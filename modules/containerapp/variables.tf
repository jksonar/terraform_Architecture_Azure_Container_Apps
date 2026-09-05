variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "container_app_environment_id" {
  type = string
}

variable "identity_id" {
  description = "Resource ID of the user-assigned managed identity this container app runs as."
  type        = string
}

variable "identity_client_id" {
  description = "Client ID of that same identity, injected as AZURE_CLIENT_ID so the app SDK can select it."
  type        = string
}

variable "registry_login_server" {
  type = string
}

variable "container_image" {
  type = string
}

variable "target_port" {
  type = number
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = string
}

variable "min_replicas" {
  type = number
}

variable "max_replicas" {
  type = number
}

variable "env_vars" {
  description = "Plain-text environment variables to inject into the container (e.g. downstream endpoints, non-secret config)."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Key Vault-backed secrets exposed to the container, as { container-app-secret-name = key_vault_secret_id }. The secret's own identity block reuses var.identity_id, which must hold a data-plane role (e.g. Key Vault Secrets User) on the vault."
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Environment variables sourced from var.secrets, as { ENV_VAR_NAME = secret-name }."
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
