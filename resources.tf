resource "random_uuid" "resource" {}

resource "aws_eks_cluster" "resource" {
  name     = coalesce(var.name, random_uuid.resource.id)
  role_arn = var.role_arn
  version  = var.kubernetes_version

  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.security_group_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = var.kms_key_arn
    }
  }

  dynamic "kubernetes_network_config" {
    for_each = var.service_ipv4_cidr == null && var.ip_family == null ? [] : [1]

    content {
      service_ipv4_cidr = var.service_ipv4_cidr
      ip_family         = var.ip_family
    }
  }

  upgrade_policy {
    support_type = var.support_type
  }

  tags = var.tags
}

resource "aws_iam_openid_connect_provider" "resource" {
  count = var.enable_irsa ? 1 : 0

  url            = aws_eks_cluster.resource.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]

  tags = var.tags
}

output "id" {
  description = "The ID of the cluster."
  value       = aws_eks_cluster.resource.id
}

output "arn" {
  description = "The ARN of the cluster."
  value       = aws_eks_cluster.resource.arn
}

output "name" {
  description = "The name of the cluster. Feed this into terraform-aws-eks-node-group's cluster_name, and into kubectl's --name when writing kubeconfig."
  value       = aws_eks_cluster.resource.name
}

output "endpoint" {
  description = "The HTTPS endpoint of the Kubernetes API server."
  value       = aws_eks_cluster.resource.endpoint
}

output "certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster. Needed by any client authenticating to the API server."
  value       = aws_eks_cluster.resource.certificate_authority[0].data
}

output "kubernetes_version" {
  description = "The Kubernetes minor version actually running on the control plane, which is the resolved value when kubernetes_version was left null."
  value       = aws_eks_cluster.resource.version
}

output "cluster_security_group_id" {
  description = "The ID of the security group EKS creates for the cluster. Node groups need to reach the control plane through this — it is not one of the security_group_ids you pass in."
  value       = aws_eks_cluster.resource.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL of the cluster, used to build the trust policy of an IRSA role."
  value       = aws_eks_cluster.resource.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the IAM OIDC provider, or null when enable_irsa is false. This is the Federated principal in an IRSA role's trust policy."
  value       = one(aws_iam_openid_connect_provider.resource[*].arn)
}

output "status" {
  description = "The status of the cluster."
  value       = aws_eks_cluster.resource.status
}
