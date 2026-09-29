mock_provider "aws" {
  mock_resource "aws_eks_cluster" {
    defaults = {
      certificate_authority = [{ data = "TU9DS0VE" }]

      identity = [{
        oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE" }]
      }]
    }
  }
}

variables {
  role_arn    = "arn:aws:iam::123456789012:role/example"
  subnet_ids  = ["subnet-00000000000000001", "subnet-00000000000000002"]
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
}

run "kms_key_is_required" {
  command = plan

  variables {
    kms_key_arn = null
  }

  expect_failures = [var.kms_key_arn]
}

run "defaults_are_private_and_audited" {
  command = apply

  variables {
    enable_irsa = false
  }

  assert {
    condition     = aws_eks_cluster.resource.name == random_uuid.resource.id
    error_message = "With no name given, the cluster should use the generated random_uuid."
  }

  assert {
    condition     = aws_eks_cluster.resource.vpc_config[0].endpoint_private_access
    error_message = "endpoint_private_access should default to true."
  }

  assert {
    condition     = aws_eks_cluster.resource.vpc_config[0].endpoint_public_access == false
    error_message = "endpoint_public_access should default to false — the API server is not exposed to the internet unless asked for."
  }

  assert {
    condition     = length(aws_eks_cluster.resource.vpc_config[0].public_access_cidrs) == 0
    error_message = "No public access CIDRs should be set while the public endpoint is disabled."
  }

  assert {
    condition     = aws_eks_cluster.resource.access_config[0].authentication_mode == "API"
    error_message = "authentication_mode should default to API — access entries, not the legacy aws-auth ConfigMap."
  }

  assert {
    condition     = aws_eks_cluster.resource.access_config[0].bootstrap_cluster_creator_admin_permissions
    error_message = "The creating principal should get admin access by default, or nobody can administer the cluster."
  }

  assert {
    condition     = contains(aws_eks_cluster.resource.enabled_cluster_log_types, "audit")
    error_message = "Audit logging should be on by default."
  }

  assert {
    condition     = aws_eks_cluster.resource.upgrade_policy[0].support_type == "STANDARD"
    error_message = "support_type should default to STANDARD, not the higher-priced EXTENDED."
  }

  assert {
    condition     = length(aws_eks_cluster.resource.encryption_config) == 1
    error_message = "Secrets should always be envelope-encrypted — the encryption_config block is not optional."
  }

  assert {
    condition     = length(aws_eks_cluster.resource.kubernetes_network_config) == 0
    error_message = "kubernetes_network_config should be omitted when neither service_ipv4_cidr nor ip_family is set."
  }
}

run "explicit_name_overrides_generated_uuid" {
  command = plan

  variables {
    name = "example"
  }

  assert {
    condition     = aws_eks_cluster.resource.name == "example"
    error_message = "An explicit name should be used instead of the generated UUID."
  }
}

run "public_access_cidrs_apply_when_public_endpoint_is_enabled" {
  command = plan

  variables {
    endpoint_public_access = true
    public_access_cidrs    = ["203.0.113.0/24"]
  }

  assert {
    condition     = aws_eks_cluster.resource.vpc_config[0].endpoint_public_access
    error_message = "endpoint_public_access should be true when asked for."
  }

  assert {
    condition     = aws_eks_cluster.resource.vpc_config[0].public_access_cidrs == toset(["203.0.113.0/24"])
    error_message = "public_access_cidrs should be passed through when the public endpoint is enabled."
  }
}

run "public_access_cidrs_are_dropped_when_the_public_endpoint_is_off" {
  command = plan

  variables {
    endpoint_public_access = false
    public_access_cidrs    = ["203.0.113.0/24"]
  }

  assert {
    condition     = length(aws_eks_cluster.resource.vpc_config[0].public_access_cidrs) == 0
    error_message = "public_access_cidrs is meaningless with the public endpoint off and should not be sent."
  }
}

run "kms_key_encrypts_secrets" {
  command = plan

  assert {
    condition     = aws_eks_cluster.resource.encryption_config[0].resources == toset(["secrets"])
    error_message = "Envelope encryption should cover Kubernetes secrets."
  }

  assert {
    condition     = aws_eks_cluster.resource.encryption_config[0].provider[0].key_arn == "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    error_message = "The supplied KMS key should be the envelope encryption key."
  }
}

run "irsa_provider_is_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_openid_connect_provider.resource) == 1
    error_message = "The IAM OIDC provider should be created by default so IRSA works."
  }
}

run "irsa_can_be_disabled" {
  command = plan

  variables {
    enable_irsa = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.resource) == 0
    error_message = "No OIDC provider should be created when enable_irsa is false."
  }
}

run "service_cidr_sets_the_network_config_block" {
  command = plan

  variables {
    service_ipv4_cidr = "10.100.0.0/16"
  }

  assert {
    condition     = length(aws_eks_cluster.resource.kubernetes_network_config) == 1
    error_message = "Setting service_ipv4_cidr should produce a kubernetes_network_config block."
  }

  assert {
    condition     = aws_eks_cluster.resource.kubernetes_network_config[0].service_ipv4_cidr == "10.100.0.0/16"
    error_message = "service_ipv4_cidr should be passed through."
  }
}

run "logging_can_be_turned_off" {
  command = plan

  variables {
    enabled_cluster_log_types = []
  }

  assert {
    condition     = length(aws_eks_cluster.resource.enabled_cluster_log_types) == 0
    error_message = "An empty enabled_cluster_log_types should disable control plane logging entirely."
  }
}

run "pinned_version_is_passed_through" {
  command = plan

  variables {
    kubernetes_version = "1.31"
  }

  assert {
    condition     = aws_eks_cluster.resource.version == "1.31"
    error_message = "An explicit kubernetes_version should be sent to the control plane."
  }
}
