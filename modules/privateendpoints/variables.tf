variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "subnet_id" {
  description = "Subnet to place the private endpoints in."
  type        = string
}

variable "container_registry_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "cosmosdb_account_id" {
  type = string
}

variable "enable_acr_private_endpoint" {
  description = "Whether to create a private endpoint (and DNS zone) for the container registry. Requires the registry to be Premium SKU."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
