variable "name" {
  description = "Name of the virtual network."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "appgw_subnet_prefix" {
  description = "Address prefix for the Application Gateway subnet. Must be dedicated to Application Gateway only."
  type        = string
}

variable "container_apps_subnet_prefix" {
  description = "Address prefix for the Container Apps environment infrastructure subnet."
  type        = string
}

variable "private_endpoints_subnet_prefix" {
  description = "Address prefix for the private endpoints subnet."
  type        = string
}

variable "postgresql_subnet_prefix" {
  description = "Address prefix for the PostgreSQL Flexible Server delegated subnet."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
