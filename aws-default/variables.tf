variable "aws_region" {
  description = "The AWS region to provision resources"
  type        = string
  default     = "sa-east-1"
}

variable "eks_cluster_name" {
  description = "The EKS cluster name"
  type        = string
  default     = "cps1-main"
}

variable "eks_admins" {
  description = "IAM users with admin capabilities"
  type        = list(string)
  default     = []
}

variable "ack_enable_rds" {
  description = "Create related resources to spin up RDS instances in CPS1 managed environments"
  type        = bool
  default     = false
}

variable "rds_subnet_group_name" {
  description = "The name of the subnet group to configure access between CPS1 workspaces and RDS instances"
  type        = string
  default     = "cps1eks"
}

variable "ack_enable_sns" {
  description = "Create related resources to create SNS topics in CPS1 managed environments"
  type        = bool
  default     = false
}

variable "ack_enable_sqs" {
  description = "Create related resources to create SQS queues in CPS1 managed environments"
  type        = bool
  default     = false
}

variable "cps1_user_namespace_prefix" {
  description = "The prefix for user namespaces in your CPS1 instance"
  type        = string
  default     = "u-"
}
