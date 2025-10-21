# Cloud Programming Shell (CPS1) Terraform blueprints

[Cloud Programming Shell (CPS)1](https://cps1.tech) is a Cloud Development Environment (CDE) on your Kubernetes that lets Devs launch environments on demand while Ops avoids tickets and keeps compute usage and security under control.

This repository provides Terraform blueprints to help provision Kubernetes clusters on various cloud providers, ready to deploy CPS1. It is a starting point for DevOps engineers, platform engineers, and SREs.

We currently support Amazon Web Services (AWS) Elastic Kubernetes Service (EKS); more providers are planned.

After provisioing a Kubernetes cluster, refer to the documentation for installing CPS1: [https://docs.cps1.tech](https://docs.cps1.tech)    

## AWS EKS

Module Overview:
- An EKS cluster with a managed node group.
- Common EKS addons (cert-manager, ingress-nginx, AWS Load Balancer Controller, EBS CSI driver via IRSA).
- StorageClasses and small Kubernetes resources required by the addons.
- A VPC with public and private subnets (NAT gateway for private outbound access).
- This deployment will incur AWS charges (EKS control plane, EC2 nodes, NAT gateway, ELBs, EBS volumes). Review costs before applying.

### Prerequisites

- Terraform (>= 1.x)
- AWS CLI installed and configured with credentials for the target account
- kubectl and helm for interacting with the created cluster
- Local environment able to run `aws eks get-token` (providers use `exec` to authenticate to the cluster)

### Required variables
Provide values via `terraform.tfvars` or `-var` arguments. Example minimal `terraform.tfvars`:

```hcl
aws_region       = "us-west-2"
eks_cluster_name = "my-cps1-cluster"
eks_admins       = ["arn:aws:iam::123456789012:user/admin"]
```

Adjust values for your environment. `eks_admins` should be a list of ARNs that will be granted cluster admin access.

### Example usage

```bash
export AWS_PROFILE=your-profile  # or configure env vars

terraform init
terraform plan
terraform apply
```

To destroy resources:

```bash
terraform destroy
```
