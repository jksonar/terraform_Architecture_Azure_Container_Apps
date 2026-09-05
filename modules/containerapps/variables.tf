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
  description = "Used to link the environment's own private DNS zone (default_domain) so callers inside the VNet can resolve each container app's FQDN."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
