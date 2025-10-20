variable "eks_cluster_name" {
  description = "The EKS cluster name"
  type        = string
  default     = "cps1-main"
}

variable "eks_group_name" {
  description = "The EKS nodes group"
  type        = string
  default     = "cps1-main-nodes"
}

variable "aws_region" {
  description = "The AWS region to provision resources"
  type        = string
  default     = "sa-east-1"
}
