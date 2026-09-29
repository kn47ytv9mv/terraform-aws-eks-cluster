variable "name" {
  default     = null
  description = "Name of the cluster."
}

variable "role_arn" {
  default     = null
  description = "The ARN of the IAM role the EKS control plane assumes. Needs the AmazonEKSClusterPolicy managed policy."
}

variable "kubernetes_version" {
  default     = null
  description = "Kubernetes minor version for the control plane (e.g. '1.31'). Left null, AWS picks the current default, which moves over time — pin it for anything you intend to keep."
}

variable "subnet_ids" {
  default     = []
  description = "IDs of the subnets the control plane's elastic network interfaces are placed in. At least two, in different availability zones. Private subnets are the usual choice."
}

variable "security_group_ids" {
  default     = null
  description = "IDs of additional security groups to attach to the control plane's network interfaces. EKS always creates its own cluster security group on top of these."
}

variable "endpoint_private_access" {
  default     = true
  description = "Whether the Kubernetes API endpoint is reachable from inside the VPC."
}

variable "endpoint_public_access" {
  default     = false
  description = "Whether the Kubernetes API endpoint is reachable from the internet. Defaults to false, which means kubectl only works from inside the VPC or across a VPN — see the README before changing it."
}

variable "public_access_cidrs" {
  default     = null
  description = "CIDR blocks allowed to reach the public endpoint. Only meaningful when endpoint_public_access is true. Left null with public access on, AWS allows 0.0.0.0/0."
}

variable "authentication_mode" {
  default     = "API"
  description = "How access to the cluster is granted (e.g. 'API', 'API_AND_CONFIG_MAP', or 'CONFIG_MAP'). 'API' uses EKS access entries; the aws-auth ConfigMap is the legacy path."
}

variable "bootstrap_cluster_creator_admin_permissions" {
  default     = true
  description = "Whether the principal that creates the cluster is granted cluster administrator access. Set false only if you are granting access another way, or nobody can administer the cluster."
}

variable "kms_key_arn" {
  default     = null
  description = "The ARN of a customer managed KMS key used to envelope-encrypt Kubernetes secrets at rest. Required — EKS envelope encryption cannot use an AWS-managed key, so there is no cheaper way to get it. Feed this from terraform-aws-kms-key."

  validation {
    condition     = var.kms_key_arn != null
    error_message = "kms_key_arn is required. Kubernetes secrets sit in etcd, and envelope-encrypting them needs a customer managed KMS key — create one with terraform-aws-kms-key."
  }
}

variable "enabled_cluster_log_types" {
  default     = ["api", "audit", "authenticator"]
  description = "Control plane log types shipped to CloudWatch Logs (e.g. 'api', 'audit', 'authenticator', 'controllerManager', 'scheduler'). These are billed as CloudWatch Logs ingestion — see the README's cost note. Set to [] to disable."
}

variable "service_ipv4_cidr" {
  default     = null
  description = "CIDR block Kubernetes assigns service IP addresses from. Must not overlap the VPC. Left null, AWS picks 10.100.0.0/16 or 172.20.0.0/16."
}

variable "ip_family" {
  default     = null
  description = "IP family for service addresses (e.g. 'ipv4' or 'ipv6'). Left null, AWS uses ipv4."
}

variable "support_type" {
  default     = "STANDARD"
  description = "Version support policy (e.g. 'STANDARD' or 'EXTENDED'). 'EXTENDED' keeps a minor version supported past its standard window and is billed at a higher hourly rate."
}

variable "enable_irsa" {
  default     = true
  description = "Whether to create the IAM OIDC provider for the cluster, which is what lets a Kubernetes service account assume an IAM role (IRSA). Almost always wanted; without it, pods authenticate with node instance profiles instead."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the cluster and the OIDC provider."
}
