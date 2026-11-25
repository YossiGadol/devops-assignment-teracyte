# Lifecycle policy for the IMAGES account only. Azure allows one policy per account; the models
# account has no azurerm_storage_management_policy, so nothing ever expires model artifacts.
#
# Days are counted from blob CREATION (ingest), not last modification, so the policy matches the
# worksheet ("hot for 7 days, cool through day 30") even if blob metadata is touched later.
# Azure evaluates policies about once a day: an action can run up to ~24 h after its threshold.
resource "azurerm_storage_management_policy" "images" {
  storage_account_id = azurerm_storage_account.images.id

  rule {
    name    = "raw-images-hot-cool-delete"
    enabled = true

    filters {
      # prefix_match is "<container>/<blob name prefix>"; this covers every blob in raw-images.
      prefix_match = ["${azurerm_storage_container.this["raw_images"].name}/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_creation_greater_than = var.retention.raw_hot_days
        delete_after_days_since_creation_greater_than       = var.retention.raw_delete_days
      }
    }
  }

  rule {
    name    = "masks-hot-delete"
    enabled = true

    filters {
      prefix_match = ["${azurerm_storage_container.this["masks"].name}/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_creation_greater_than = var.retention.mask_delete_days
      }
    }
  }
}
