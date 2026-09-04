variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  description = "Must be Premium to support private endpoints."
  type        = string
  default     = "Premium"
}

variable "tags" {
  type    = map(string)
  default = {}
}
