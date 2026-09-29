# terraform-aws-eks-cluster

Terraform module for an EKS control plane and, unless it is turned off,
the IAM OIDC provider that goes with it. The two are bundled because a
cluster without the OIDC provider cannot do IRSA, and almost every cluster
wants IRSA.

## Cost

Unlike most modules in this family, this one carries a standing charge
that does not depend on usage. An EKS control plane is billed per hour
from the moment it exists, whether or not a single pod is scheduled. There
is no free tier and no scale to zero, so a cluster left running costs the
same as one under load. Destroy clusters that are not in use.

Two settings multiply that. `support_type = "EXTENDED"` raises the control
plane rate substantially in exchange for continued support of a Kubernetes
minor version past its standard window; staying on a supported version is
far cheaper than paying to sit on an old one. Control plane logs are
billed as CloudWatch Logs ingestion and storage, and `audit` is by some
distance the highest-volume type on a busy cluster.

The required customer managed KMS key carries a small monthly charge plus
a per-request cost. That is the entire price of encrypting Kubernetes
secrets, which is why this module does not make it optional.

Nodes, load balancers, NAT gateways and storage are not this module's
cost. See `terraform-aws-eks-node-group` and `terraform-aws-vpc`. Current
rates are on AWS's [EKS pricing](https://aws.amazon.com/eks/pricing/) page.

## Design

Defaults are private. The Kubernetes API endpoint is reachable from inside
the VPC and not from the internet, access is granted through EKS access
entries rather than the legacy `aws-auth` ConfigMap, and API, audit and
authenticator logs are on.

### Secret encryption is required

`kms_key_arn` is required. Kubernetes secrets live in etcd, and
envelope-encrypting them is the one protection that is not already on by
default elsewhere. EKS cannot do it with an AWS-managed key, so a customer
managed key is the only way to have it at all, and a module that made it
optional would ship an insecure default. Build the key with
`terraform-aws-kms-key`.

### Reaching the API server

The private endpoint default is a decision rather than an oversight. A
public EKS endpoint left at its own default is open to the entire
internet, with authentication alone standing between a stranger and the
API server. This module starts closed.

That means `kubectl` works from inside the VPC: a bastion, a CI runner in
a private subnet, or across a VPN or Direct Connect. Where access from
outside is genuinely needed, set `endpoint_public_access` **and**
`public_access_cidrs` together. Setting the first without the second
yields AWS's own default of the whole internet.

`public_access_cidrs` is dropped entirely while the public endpoint is
off, so a value left in place does nothing until the endpoint is enabled.

### What this module does not create

No nodes: use `terraform-aws-eks-node-group`, or Fargate profiles. Not the
cluster IAM role: pass `role_arn`, built with `terraform-aws-iam-role` and
the `AmazonEKSClusterPolicy` managed policy. Not add-ons beyond the EKS
defaults of VPC CNI, CoreDNS and kube-proxy. Not a `kubeconfig` file: take
`name`, `endpoint` and `certificate_authority_data` from the outputs.

### IRSA

With `enable_irsa` left at its default the module registers the cluster's
OIDC issuer as an IAM identity provider. A role that a Kubernetes service
account assumes uses `oidc_provider_arn` as the federated principal and
`oidc_issuer_url` to build the subject condition key. Both are outputs.

## Usage

```hcl
module "cluster" {
  source = "kn47ytv9mv/eks-cluster/aws"

  name     = "example"
  role_arn = module.cluster_role.arn

  kubernetes_version = "1.31"
  subnet_ids         = module.private_subnets[*].id

  kms_key_arn = module.kms_key.arn
}
```

Or directly from this repository:

```hcl
module "cluster" {
  source = "github.com/kn47ytv9mv/terraform-aws-eks-cluster"

  name     = "example"
  role_arn = module.cluster_role.arn

  kubernetes_version = "1.31"
  subnet_ids         = module.private_subnets[*].id

  kms_key_arn = module.kms_key.arn
}
```

With the API server reachable from one office range:

```hcl
module "cluster" {
  source = "kn47ytv9mv/eks-cluster/aws"

  name     = "example"
  role_arn = module.cluster_role.arn

  kubernetes_version = "1.31"
  subnet_ids         = module.private_subnets[*].id

  kms_key_arn = module.kms_key.arn

  endpoint_public_access = true
  public_access_cidrs    = ["203.0.113.0/24"]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.2 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the cluster. | `null` | no |
| role_arn | The ARN of the IAM role the EKS control plane assumes. | `null` | no |
| kubernetes_version | Kubernetes minor version for the control plane. Left null, AWS picks its current default, which moves over time. | `null` | no |
| subnet_ids | IDs of the subnets the control plane's network interfaces are placed in. At least two, in different availability zones. | `[]` | no |
| security_group_ids | IDs of additional security groups for the control plane's network interfaces. | `null` | no |
| endpoint_private_access | Whether the Kubernetes API endpoint is reachable from inside the VPC. | `true` | no |
| endpoint_public_access | Whether the Kubernetes API endpoint is reachable from the internet. | `false` | no |
| public_access_cidrs | CIDR blocks allowed to reach the public endpoint. | `null` | no |
| authentication_mode | How access is granted (e.g. `'API'`, `'API_AND_CONFIG_MAP'`, `'CONFIG_MAP'`). | `"API"` | no |
| bootstrap_cluster_creator_admin_permissions | Whether the creating principal is granted cluster administrator access. | `true` | no |
| kms_key_arn | The ARN of a customer managed KMS key used to envelope-encrypt Kubernetes secrets. Required. | `null` | **yes** |
| enabled_cluster_log_types | Control plane log types shipped to CloudWatch Logs. | `["api", "audit", "authenticator"]` | no |
| service_ipv4_cidr | CIDR block Kubernetes assigns service addresses from. Must not overlap the VPC. | `null` | no |
| ip_family | IP family for service addresses (e.g. `'ipv4'` or `'ipv6'`). | `null` | no |
| support_type | Version support policy (e.g. `'STANDARD'` or `'EXTENDED'`). | `"STANDARD"` | no |
| enable_irsa | Whether to create the IAM OIDC provider that lets a service account assume an IAM role. | `true` | no |
| tags | A map of tags to assign to the cluster and the OIDC provider. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the cluster. |
| arn | The ARN of the cluster. |
| name | The name of the cluster. Feed into `terraform-aws-eks-node-group`'s `cluster_name`. |
| endpoint | The HTTPS endpoint of the Kubernetes API server. |
| certificate_authority_data | Base64-encoded certificate authority data for the cluster. |
| kubernetes_version | The Kubernetes minor version running on the control plane. |
| cluster_security_group_id | The ID of the security group EKS creates for the cluster. |
| oidc_issuer_url | The OIDC issuer URL, used to build the condition key of an IRSA role. |
| oidc_provider_arn | The ARN of the IAM OIDC provider, or null when `enable_irsa` is false. |
| status | The status of the cluster. |

## License

MIT — see [LICENSE.md](LICENSE.md).
