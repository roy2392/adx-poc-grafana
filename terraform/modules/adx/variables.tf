variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ADX cluster"
  type        = string
}

variable "sku_name" {
  description = "ADX cluster SKU"
  type        = string
}

variable "capacity" {
  description = "Number of instances in the cluster"
  type        = number
  default     = 1
}

variable "database_name" {
  description = "Name of the ADX database"
  type        = string
}

variable "hot_cache_period" {
  description = "Hot cache period (ISO 8601 duration)"
  type        = string
  default     = "P7D"
}

variable "soft_delete_period" {
  description = "Soft delete period (ISO 8601 duration)"
  type        = string
  default     = "P31D"
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access ADX"
  type        = list(string)
  default     = []
}

variable "enable_streaming_ingestion" {
  description = "Enable streaming ingestion"
  type        = bool
  default     = true
}

variable "enable_purge" {
  description = "Enable data purge capability"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
