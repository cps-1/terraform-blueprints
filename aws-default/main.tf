provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project  = "CPS1"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  # Do not include local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name   = var.eks_cluster_name
  region = var.aws_region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
}

################################################################################
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name                   = local.name
  cluster_version                = "1.34"
  cluster_endpoint_public_access = true

  # Give the Terraform identity admin access to the cluster
  # which will allow resources to be deployed into the cluster
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  access_entries = {
    for admin_arn in var.eks_admins :
    admin_arn => {
      principal_arn = admin_arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    main = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.xlarge"]

      min_size     = 1
      max_size     = 3
      desired_size = 1
      subnets = slice(module.vpc.private_subnets, 0, 1)

      block_device_mappings = {
        xvdb = {
          device_name = "/dev/xvdb"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            iops                  = 3000
            delete_on_termination = true
          }
        }
      }
    }
  }
}

################################################################################
# EKS Blueprints Addons
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.22"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_delay_dependencies = [for group in module.eks.eks_managed_node_groups : group.node_group_arn]

  eks_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
  }

  enable_cert_manager = true
  cert_manager = {
    chart_version    = "v1.16.1"
    namespace        = "cert-manager"
    create_namespace = true
  }

  enable_ingress_nginx = true
  ingress_nginx = {
    name          = "ingress-nginx"
    chart_version = "4.13.0"
    repository    = "https://kubernetes.github.io/ingress-nginx"
    namespace     = "ingress-nginx"
    values = [
      <<-EXTRA_VALUES
      controller:
        service:
          externalTrafficPolicy: Local
          annotations:
            service.beta.kubernetes.io/aws-load-balancer-name: "${local.name}-public-lb"
            service.beta.kubernetes.io/aws-load-balancer-type: "external"
            service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
            service.beta.kubernetes.io/aws-load-balancer-attributes: load_balancing.cross_zone.enabled=true
            service.beta.kubernetes.io/load-balancer-source-ranges: 0.0.0.0/0
          loadBalancerClass: service.k8s.aws/nlb
    EXTRA_VALUES
    ]
  }

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version = "1.13.3"
    set = [
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      }
    ]
  }
}

################################################################################
# Storage Classes
################################################################################

resource "kubernetes_annotations" "gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  # This is true because the resources was already created by the ebs-csi-driver addon
  force = "true"

  metadata {
    name = "gp2"
  }

  annotations = {
    # Modify annotations to remove gp2 as default storage class still retain the class
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    fsType    = "ext4"
    type      = "gp3"
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${module.eks.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

