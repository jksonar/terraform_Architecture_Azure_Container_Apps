variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "offer_type" {
  type    = string
  default = "Standard"
}

variable "consistency_level" {
  type    = string
  default = "Session"
}

variable "database_name" {
  type    = string
  default = "appdb"
}

variable "container_name" {
  type    = string
  default = "items"
}

variable "partition_key_path" {
  type    = string
  default = "/id"
}

variable "tags" {
  type    = map(string)
  default = {}
}
