output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "rds_security_group" {
  description = "Security group ID to use for instancing RDS for CPS1 environments"
  value = length(aws_security_group.cps1eksrds) > 0 ? aws_security_group.cps1eksrds[0].id : null
}

output "workspace_role_arn" {
  description = "ARN Role to use in workspaces' Service Account"
  value       = length(aws_iam_role.cps1workspace) > 0 ? aws_iam_role.cps1workspace[0].arn : null
}
