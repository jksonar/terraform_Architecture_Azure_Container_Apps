variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "public_ip_id" {
  description = "Resource ID of the (caller-managed) public IP for the gateway's frontend. Kept out of this module so other resources can depend on the IP address without depending on the gateway itself."
  type        = string
}

variable "django_todo_backend_fqdn" {
  description = "FQDN of the internal Django Todo Container App."
  type        = string
}

variable "django_todo_path_pattern" {
  type    = string
  default = "/tasks/*"
}

variable "django_todo_health_path" {
  type    = string
  default = "/tasks/health/"
}

variable "cosmos_crud_backend_fqdn" {
  description = "FQDN of the internal Cosmos CRUD Container App."
  type        = string
}

variable "cosmos_crud_path_pattern" {
  type    = string
  default = "/cosmos_crud/*"
}

variable "cosmos_crud_health_path" {
  type    = string
  default = "/cosmos_crud/health/"
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 5
}

variable "tags" {
  type    = map(string)
  default = {}
}
