variable "eks_cluster_name" {
  description = "The EKS cluster name"
  type        = string
  default     = "cps1-main"
}

variable "aws_region" {
  description = "The AWS region to provision resources"
  type        = string
  default     = "sa-east-1"
}

variable "eks_admins" {
  description = "IAM users with admin capabilities"
  type        = list(string)
  default = []
}
