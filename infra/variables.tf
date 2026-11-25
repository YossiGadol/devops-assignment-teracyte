variable "subscription_id" {
  description = "Azure subscription ID. Null = take it from ARM_SUBSCRIPTION_ID or the Azure CLI context."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region. Use the AKS cluster's region to avoid cross-region transfer charges."
  type        = string
  default     = "westeurope"
}

variable "name_prefix" {
  description = "Short lowercase alphanumeric prefix. Storage account names are global, so make it specific to your organisation."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.name_prefix))
    error_message = "name_prefix must be 3-10 lowercase letters or digits (storage account names allow only [a-z0-9], max 24)."
  }
}

variable "environment" {
  description = "Environment name, used in resource names and tags (e.g. dev, prod)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.environment))
    error_message = "environment must be 2-6 lowercase letters or digits."
  }
}

variable "name_suffix" {
  description = "Optional extra characters to make storage account names globally unique (e.g. 01)."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]{0,5}$", var.name_suffix))
    error_message = "name_suffix must be 0-5 lowercase letters or digits."
  }
}

variable "replication_type" {
  description = "Redundancy for both accounts. ZRS survives a zone outage (the cluster spans zones 1-3); LRS is cheaper for dev."
  type        = string
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS"], var.replication_type)
    error_message = "replication_type must be LRS, ZRS, GRS or GZRS."
  }
}

variable "retention" {
  description = <<-EOT
    Image retention, in days since blob creation. Defaults = the worksheet's alternative policy.
    raw_hot_days:     raw images move hot -> cool after this many days.
    raw_delete_days:  raw images are deleted after this many days.
    mask_delete_days: masks are deleted after this many days (they stay hot until then).
    Model artifacts live in a separate account and are never covered by these rules.
  EOT
  type = object({
    raw_hot_days     = optional(number, 7)
    raw_delete_days  = optional(number, 30)
    mask_delete_days = optional(number, 30)
  })
  default = {}

  validation {
    condition     = var.retention.raw_hot_days >= 1 && var.retention.raw_delete_days > var.retention.raw_hot_days
    error_message = "raw_hot_days must be >= 1 and raw_delete_days must be greater than raw_hot_days."
  }

  validation {
    condition     = var.retention.mask_delete_days >= 1
    error_message = "mask_delete_days must be >= 1."
  }
}

variable "images_soft_delete_days" {
  description = <<-EOT
    Blob soft delete for the images account, in days. 0 = disabled (default).
    With soft delete on, every lifecycle deletion is kept and billed for this many extra days.
  EOT
  type        = number
  default     = 0

  validation {
    condition     = var.images_soft_delete_days >= 0 && var.images_soft_delete_days <= 365
    error_message = "images_soft_delete_days must be between 0 and 365."
  }
}

variable "models_soft_delete_days" {
  description = "Blob and container soft delete for the models account, in days. Protects published models from accidental deletion."
  type        = number
  default     = 30

  validation {
    condition     = var.models_soft_delete_days >= 1 && var.models_soft_delete_days <= 365
    error_message = "models_soft_delete_days must be between 1 and 365."
  }
}

variable "public_network_access_enabled" {
  description = <<-EOT
    false (default): the accounts are reachable only through private endpoints (an external dependency).
    true: the public endpoint is on but default-deny; only allowed_subnet_ids / allowed_ip_ranges get in.
    Anonymous blob access is disabled either way.
  EOT
  type        = bool
  default     = false
}

variable "allowed_subnet_ids" {
  description = "Subnet IDs (with the Microsoft.Storage service endpoint) allowed through the firewall when public_network_access_enabled = true."
  type        = list(string)
  default     = []
}

variable "allowed_ip_ranges" {
  description = "Public IPs/CIDRs allowed through the firewall when public_network_access_enabled = true (e.g. an operator's egress IP)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}
