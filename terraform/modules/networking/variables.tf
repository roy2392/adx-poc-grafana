variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "address_space" {
  description = "VNet address space"
  type        = string
  default     = "10.0.0.0/16"
}

variable "adx_subnet_prefix" {
  description = "ADX subnet address prefix"
  type        = string
  default     = "10.0.1.0/24"
}

variable "aci_subnet_prefix" {
  description = "Container Instance subnet address prefix"
  type        = string
  default     = "10.0.2.0/24"
}

variable "bastion_subnet_prefix" {
  description = "Bastion subnet address prefix"
  type        = string
  default     = "10.0.3.0/27"
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion for secure access"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
