variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "infrastructure_subnet_id" {
  type = string
}

variable "workload_profile_enabled" {
  type    = bool
  default = true
}

variable "vnet_id" {
  description = "Used to link the environment's own private DNS zone (default_domain) so callers inside the VNet can resolve the app's FQDN."
  type        = string
}

variable "identity_id" {
  description = "Resource ID of the user-assigned managed identity the container app runs as."
  type        = string
}

variable "identity_client_id" {
  description = "Client ID of that same identity, injected as AZURE_CLIENT_ID so the app SDK can select it."
  type        = string
}

variable "registry_login_server" {
  type = string
}

variable "container_image" {
  type = string
}

variable "target_port" {
  type = number
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = string
}

variable "min_replicas" {
  type = number
}

variable "max_replicas" {
  type = number
}

variable "env_vars" {
  description = "Extra plain-text environment variables to inject into the container (e.g. downstream endpoints)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
