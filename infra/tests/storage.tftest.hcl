# Credential-free checks of the storage contract. `mock_provider` replaces azurerm, so these run in CI
# without an Azure account: they test what Terraform would request, not what Azure would accept.
# Run from infra/: terraform test

mock_provider "azurerm" {}

# Mocked IDs must look like real ARM IDs: azurerm parses storage_account_id. Distinct IDs let the
# tests prove which account each container and the lifecycle policy are attached to.
override_resource {
  target = azurerm_storage_account.images
  values = {
    id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/imagesmock"
    primary_blob_endpoint = "https://imagesmock.blob.core.windows.net/"
  }
}

override_resource {
  target = azurerm_storage_account.models
  values = {
    id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/modelsmock"
    primary_blob_endpoint = "https://modelsmock.blob.core.windows.net/"
  }
}

variables {
  name_prefix = "tcyte"
  environment = "ci"
}

run "worksheet_policy_and_private_accounts" {
  # apply against the mock provider (no Azure calls) so resource IDs are known for the assertions.
  command = apply

  # --- raw images: hot 7 days -> cool -> deleted after 30 days (counted from creation) ---
  assert {
    condition     = azurerm_storage_management_policy.images.rule[0].filters[0].prefix_match == toset(["raw-images/"])
    error_message = "Raw-image rule must target only the raw-images container."
  }
  assert {
    condition     = azurerm_storage_management_policy.images.rule[0].actions[0].base_blob[0].tier_to_cool_after_days_since_creation_greater_than == 7
    error_message = "Raw images must move to cool after 7 days."
  }
  assert {
    condition     = azurerm_storage_management_policy.images.rule[0].actions[0].base_blob[0].delete_after_days_since_creation_greater_than == 30
    error_message = "Raw images must be deleted after 30 days."
  }

  # --- masks: hot until deletion after 30 days, never tiered ---
  assert {
    condition     = azurerm_storage_management_policy.images.rule[1].filters[0].prefix_match == toset(["masks/"])
    error_message = "Mask rule must target only the masks container."
  }
  assert {
    condition     = azurerm_storage_management_policy.images.rule[1].actions[0].base_blob[0].delete_after_days_since_creation_greater_than == 30
    error_message = "Masks must be deleted after 30 days."
  }
  assert {
    condition     = azurerm_storage_management_policy.images.rule[1].actions[0].base_blob[0].tier_to_cool_after_days_since_creation_greater_than == null
    error_message = "Masks must not be tiered to cool."
  }

  # --- models: separate account, not referenced by the only lifecycle policy, versioned ---
  assert {
    condition     = azurerm_storage_container.this["models"].storage_account_id == azurerm_storage_account.models.id
    error_message = "Models container must live in the models account."
  }
  assert {
    condition     = azurerm_storage_management_policy.images.storage_account_id == azurerm_storage_account.images.id
    error_message = "The lifecycle policy must be attached to the images account only."
  }
  assert {
    condition     = azurerm_storage_account.models.blob_properties[0].versioning_enabled
    error_message = "Models account must keep blob versions."
  }

  # --- private: no anonymous access, no account keys, no public endpoint by default ---
  assert {
    condition = alltrue([
      for a in [azurerm_storage_account.images, azurerm_storage_account.models] :
      !a.allow_nested_items_to_be_public && !a.shared_access_key_enabled && !a.public_network_access_enabled
    ])
    error_message = "Both accounts must block anonymous access, shared keys and the public endpoint."
  }
  assert {
    condition     = alltrue([for c in azurerm_storage_container.this : c.container_access_type == "private"])
    error_message = "All containers must be private."
  }

  assert {
    condition     = azurerm_storage_account.images.name == "tcyteciimg" && azurerm_storage_account.models.name == "tcytecimdl"
    error_message = "Unexpected storage account names."
  }
}

run "retention_is_configurable" {
  command = plan

  variables {
    retention = { raw_hot_days = 3, raw_delete_days = 14, mask_delete_days = 10 }
  }

  assert {
    condition = (
      azurerm_storage_management_policy.images.rule[0].actions[0].base_blob[0].tier_to_cool_after_days_since_creation_greater_than == 3 &&
      azurerm_storage_management_policy.images.rule[0].actions[0].base_blob[0].delete_after_days_since_creation_greater_than == 14 &&
      azurerm_storage_management_policy.images.rule[1].actions[0].base_blob[0].delete_after_days_since_creation_greater_than == 10
    )
    error_message = "Retention inputs were not applied."
  }
}

run "rejects_delete_before_cool" {
  command = plan

  variables {
    retention = { raw_hot_days = 30, raw_delete_days = 7 }
  }

  expect_failures = [var.retention]
}

run "rejects_invalid_account_prefix" {
  command = plan

  variables {
    name_prefix = "Tera-Cyte"
  }

  expect_failures = [var.name_prefix]
}
