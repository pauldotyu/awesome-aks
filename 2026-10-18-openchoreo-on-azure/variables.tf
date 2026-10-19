variable "location" {
  description = "The Azure region where most of the resources are created."
  type        = string
  default     = "westus3"
}

variable "dns_zone_name" {
  description = "The public DNS zone hosted in Azure DNS. Subdomains such as *.apps.aks.rocks (data plane) and observer.obs.aks.rocks (observability plane) are provisioned on the same zone."
  type        = string
  default     = "aks.rocks"
}

variable "subscription_id" {
  description = "Subscription that hosts the OpenChoreo environment (AKS, Key Vault, managed identities). Pinned explicitly so the environment can never land in the subscription that holds the pre-existing Azure DNS zone, even if the Azure CLI default changes. Leave empty to use the current Azure CLI subscription."
  type        = string
  default     = ""
}

variable "manage_cert_manager_dns_role" {
  description = "Create the DNS Zone Contributor role assignment that lets cert-manager create/remove _acme-challenge TXT records. The role assignment is created in the subscription that holds the DNS zone, because an Azure RBAC assignment is a child resource of its scope. Set to false to grant it out of band instead (see README)."
  type        = bool
  default     = true
}

variable "manage_dns_a_records" {
  description = "Create the console/api A records in the Azure DNS zone. Records live in the zone that the domain's nameservers are delegated to, so they are written to the zone's subscription. Set to false to create them out of band instead (see README)."
  type        = bool
  default     = true
}

variable "create_dns_zone" {
  description = "Create the Azure DNS zone with Terraform. Leave this false when the zone already exists (it is then looked up instead) — that is the expected setup, since the domain's registrar nameservers are already delegated to Azure DNS. Set it to true only if you want Terraform to create the zone, in which case you must delegate the nameservers at the registrar yourself."
  type        = bool
  default     = false
}

variable "dns_zone_resource_group_name" {
  description = "Resource group holding the EXISTING Azure DNS zone. Required when var.create_dns_zone is false. Ignored when Terraform creates the zone."
  type        = string
  default     = ""
}

variable "dns_zone_subscription_id" {
  description = "Subscription holding the EXISTING Azure DNS zone. Leave empty when the zone lives in the current subscription. DNS zones are often hosted in a shared/connectivity subscription, in which case set this to that subscription id."
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to assign to the Azure resources."
  type        = map(string)
  default = {
    project     = "openchoreo"
    environment = "control-plane"
  }
}

# ---------------------------------------------------------------------------
# OpenChoreo hostnames
# ---------------------------------------------------------------------------

variable "console_hostname" {
  description = "Public hostname for the OpenChoreo Backstage console (TLS + DNS)."
  type        = string
  default     = "console.aks.rocks"
}

variable "api_hostname" {
  description = "Public hostname for the OpenChoreo API server (TLS + DNS)."
  type        = string
  default     = "api.aks.rocks"
}

# ---------------------------------------------------------------------------
# Let's Encrypt environment
# ---------------------------------------------------------------------------

variable "letsencrypt_environment" {
  description = "Which Let's Encrypt ACME server to use for the control-plane certificate. Use \"staging\" while testing DNS-01 and switch to \"production\" for a trusted public certificate. Both ClusterIssuers are always created; only the one named here backs cp-gateway-tls."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.letsencrypt_environment)
    error_message = "letsencrypt_environment must be \"staging\" or \"production\"."
  }
}

variable "letsencrypt_email" {
  description = "Email address sent to Let's Encrypt for expiry / account notices."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Platform engineer identity
# ---------------------------------------------------------------------------

variable "platform_engineer_group_display_name" {
  description = "Display name of the Entra group whose object id is granted the OpenChoreo platform-engineer role. Members of this group are authorized for the control plane via the `groups` JWT claim."
  type        = string
  default     = "CloudNative"
}

# Whether terraform should run the Entra out-of-band steps (declaring the
# access_as_user delegated scope and admin consent) via the Azure CLI at apply
# time. Default false: those mutations require an interactive `az login` to the
# target tenant, so they are documented in the README and run by the operator
# instead. Set true to have terraform attempt them automatically.
variable "enable_azure_cli_entra_steps" {
  description = "Run the Entra access_as_user scope declaration and admin consent via local-exec at apply time (requires an authenticated az CLI session)."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Component versions (pinned to what the validated getting-started used,
# adjusted where the task requires a specific version).
# ---------------------------------------------------------------------------

variable "cert_manager_version" {
  description = "cert-manager OCI chart version."
  type        = string
  default     = "v1.19.4"
}

variable "external_secrets_version" {
  description = "External Secrets Operator OCI chart version."
  type        = string
  default     = "2.0.1"
}

variable "kgateway_version" {
  description = "KGateway version, installed into the openchoreo-control-plane namespace. Defaults to 2.4.7, which is the first version validated against Kubernetes 1.36; kgateway 2.3.1 produces CRD validation errors on 1.36 and blocks the install. Set it to \"2.3.1\" only if you also pin var.kubernetes_version below 1.36."
  type        = string
  default     = "2.4.7"
}

variable "gateway_api_version" {
  description = "Gateway API CRDs version to install cluster-wide."
  type        = string
  default     = "v1.5.1"
}

variable "openchoreo_control_plane_version" {
  description = "OpenChoreo control-plane chart version."
  type        = string
  default     = "1.3.1"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. A minor alias (\"1.36\") pins the latest GA patch of that minor, so the cluster stays on 1.36+ while picking up patch updates. Set to null to track the AKS default instead."
  type        = string
  default     = "1.36"
  nullable    = true
}
