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

variable "backend_fqdn" {
  description = "FQDN of the backend (the internal Container App) the gateway routes to."
  type        = string
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
