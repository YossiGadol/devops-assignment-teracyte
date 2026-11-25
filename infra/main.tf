locals {
  # Two accounts, not one: an Azure lifecycle (management) policy belongs to an ACCOUNT. With models in
  # their own account, no image-expiration rule can match a model blob, whatever its name or prefix.
  account_names = {
    images = "${var.name_prefix}${var.environment}img${var.name_suffix}"
    models = "${var.name_prefix}${var.environment}mdl${var.name_suffix}"
  }

  # Containers are the portable "bucket" boundary that application config points at.
  containers = {
    raw_images = { account = "images", name = "raw-images" }
    masks      = { account = "images", name = "masks" }
    models     = { account = "models", name = "models" }
  }

  tags = merge(
    {
      environment = var.environment
      workload    = "teracyte-analysis"
      managed_by  = "terraform"
    },
    var.tags,
  )
}

resource "azurerm_resource_group" "storage" {
  name     = "rg-${var.name_prefix}-${var.environment}-storage"
  location = var.location
  tags     = local.tags
}

# -------------------------------------------------------------------------------------------------
# images account: raw images + masks. Short-lived, lifecycle-managed (lifecycle.tf).
# -------------------------------------------------------------------------------------------------
resource "azurerm_storage_account" "images" {
  name                     = local.account_names.images
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  access_tier              = "Hot" # new blobs land hot; the lifecycle policy moves raw images to cool

  # Private: no anonymous access, no account keys/SAS (Entra ID + RBAC only), TLS 1.2+.
  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  public_network_access_enabled    = var.public_network_access_enabled
  https_traffic_only_enabled       = true
  min_tls_version                  = "TLS1_2"
  cross_tenant_replication_enabled = false

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_ranges
  }

  blob_properties {
    # Image blobs are written once by ingest. Versioning would only add billed copies that the
    # base-blob lifecycle rules do not delete.
    versioning_enabled = false

    dynamic "delete_retention_policy" {
      for_each = var.images_soft_delete_days > 0 ? [var.images_soft_delete_days] : []
      content {
        days = delete_retention_policy.value
      }
    }
  }

  tags = merge(local.tags, { data_class = "images" })
}

# -------------------------------------------------------------------------------------------------
# models account: candidates, gate records, channels. Versioned, soft delete, NO lifecycle policy.
# -------------------------------------------------------------------------------------------------
resource "azurerm_storage_account" "models" {
  name                     = local.account_names.models
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  access_tier              = "Hot" # read by every cache warmup; cool would add retrieval charges

  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  public_network_access_enabled    = var.public_network_access_enabled
  https_traffic_only_enabled       = true
  min_tls_version                  = "TLS1_2"
  cross_tenant_replication_enabled = false

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_ranges
  }

  blob_properties {
    # An overwrite or delete keeps the previous version, so a wrong channel update or publish can be
    # rolled back. Candidates are write-once by convention in model_handoff.
    versioning_enabled  = true
    change_feed_enabled = true # audit log of changes to channels/ and candidates

    delete_retention_policy {
      days = var.models_soft_delete_days
    }

    container_delete_retention_policy {
      days = var.models_soft_delete_days
    }
  }

  tags = merge(local.tags, { data_class = "models" })
}

resource "azurerm_storage_container" "this" {
  for_each = local.containers

  name = each.value.name
  storage_account_id = (
    each.value.account == "images" ? azurerm_storage_account.images.id : azurerm_storage_account.models.id
  )
  container_access_type = "private"
}
