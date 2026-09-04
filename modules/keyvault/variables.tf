variable "name" {
  type = string
  validation {
    condition     = length(var.name) <= 24
    error_message = "Key Vault names must be 24 characters or fewer."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "standard"
}

variable "tags" {
  type    = map(string)
  default = {}
}
