variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "delegated_subnet_id" {
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers."
  type        = string
}

variable "vnet_id" {
  description = "VNet to link the server's private DNS zone to."
  type        = string
}

variable "sku_name" {
  description = "e.g. B_Standard_B1ms (Burstable), GP_Standard_D2s_v3 (General Purpose)."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "postgresql_version" {
  type    = string
  default = "16"
}

variable "administrator_login" {
  type    = string
  default = "psqladmin"
}

variable "database_name" {
  type = string
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "geo_redundant_backup_enabled" {
  type    = bool
  default = false
}

variable "high_availability_enabled" {
  description = "Zone-redundant HA standby. Not supported on Burstable (B_*) SKUs."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
