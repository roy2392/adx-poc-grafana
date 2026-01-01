variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "suffix" {
  description = "Random suffix for unique names"
  type        = string
}

variable "container_name" {
  description = "Name of the container group"
  type        = string
}

variable "image" {
  description = "Grafana container image"
  type        = string
  default     = "grafana/grafana-oss:10.2.0"
}

variable "cpu" {
  description = "CPU cores for the container"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory in GB for the container"
  type        = number
  default     = 1.5
}

variable "admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "adx_cluster_uri" {
  description = "ADX cluster URI"
  type        = string
}

variable "adx_cluster_name" {
  description = "ADX cluster name"
  type        = string
}

variable "adx_database_name" {
  description = "ADX database name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
