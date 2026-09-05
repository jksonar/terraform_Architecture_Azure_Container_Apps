variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "appgw_subnet_id" {
  type = string
}

variable "appgw_subnet_prefix" {
  description = "Used to scope the container-apps NSG rule that allows inbound traffic from the App Gateway subnet."
  type        = string
}

variable "container_apps_subnet_id" {
  type = string
}

variable "container_apps_subnet_prefix" {
  description = "Used to scope the postgresql NSG rule that allows inbound traffic from the Container Apps subnet."
  type        = string
}

variable "private_endpoints_subnet_id" {
  type = string
}

variable "postgresql_subnet_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
