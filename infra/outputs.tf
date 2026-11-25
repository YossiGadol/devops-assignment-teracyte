output "resource_group_name" {
  description = "Resource group that holds both storage accounts."
  value       = azurerm_resource_group.storage.name
}

output "storage_account_names" {
  description = "images = raw images + masks (lifecycle-managed); models = model artifacts (no lifecycle)."
  value = {
    images = azurerm_storage_account.images.name
    models = azurerm_storage_account.models.name
  }
}

output "storage_account_ids" {
  description = "ARM IDs for role assignments (Storage Blob Data Reader/Contributor) and private endpoints."
  value = {
    images = azurerm_storage_account.images.id
    models = azurerm_storage_account.models.id
  }
}

output "storage_locations" {
  description = "Container URLs: the only provider-specific values the workloads receive (through config or a mount)."
  value = {
    raw_images = "${azurerm_storage_account.images.primary_blob_endpoint}${azurerm_storage_container.this["raw_images"].name}"
    masks      = "${azurerm_storage_account.images.primary_blob_endpoint}${azurerm_storage_container.this["masks"].name}"
    models     = "${azurerm_storage_account.models.primary_blob_endpoint}${azurerm_storage_container.this["models"].name}"
  }
}

output "retention_policy" {
  description = "Effective retention, in days since blob creation."
  value = {
    raw_images = "hot ${var.retention.raw_hot_days}d -> cool -> delete after ${var.retention.raw_delete_days}d"
    masks      = "hot -> delete after ${var.retention.mask_delete_days}d"
    models     = "no lifecycle rule; versioning + ${var.models_soft_delete_days}d soft delete"
  }
}
