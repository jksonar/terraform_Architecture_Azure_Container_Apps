variable "environment" {
  description = "Environment name (dev/staging/prod) — used as a naming suffix and tag."
  type        = string
}

variable "prefix" {
  description = "Short name used as a prefix for all resource names."
  type        = string
  default     = "aca"
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vnet_address_space" {
  type = list(string)
}

variable "appgw_subnet_prefix" {
  type = string
}

variable "container_apps_subnet_prefix" {
  type = string
}

variable "private_endpoints_subnet_prefix" {
  type = string
}

variable "container_app_environment_workload_profile" {
  type    = bool
  default = true
}

variable "container_image" {
  description = "Container image (repository:tag). Defaults to a public sample image; point this at your ACR-hosted image after the first apply."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "container_app_target_port" {
  type    = number
  default = 80
}

variable "container_cpu" {
  type    = number
  default = 0.5
}

variable "container_memory" {
  type    = string
  default = "1Gi"
}

variable "container_app_min_replicas" {
  type    = number
  default = 1
}

variable "container_app_max_replicas" {
  type    = number
  default = 3
}

variable "cosmosdb_offer_type" {
  type    = string
  default = "Standard"
}

variable "cosmosdb_consistency_level" {
  type    = string
  default = "Session"
}

variable "cosmosdb_database_name" {
  type    = string
  default = "appdb"
}

variable "cosmosdb_container_name" {
  type    = string
  default = "items"
}

variable "cosmosdb_partition_key_path" {
  type    = string
  default = "/id"
}

variable "key_vault_sku" {
  type    = string
  default = "standard"
}

variable "acr_sku" {
  description = "Must be Premium to support private endpoints."
  type        = string
  default     = "Premium"
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "appgw_min_capacity" {
  type    = number
  default = 2
}

variable "appgw_max_capacity" {
  type    = number
  default = 5
}

variable "log_analytics_retention_days" {
  type    = number
  default = 30
}
