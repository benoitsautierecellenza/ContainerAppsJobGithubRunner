// az deployment sub create --location westeurope --template-file runner-environment.bicep
// fix issue with Key Vault
param location string = 'westeurope'
param Environment string = 'DEV'
param ResourceGroup_Name string = 'rg-Runner-${Environment}-${location}'
param User_Assigned_Identity_Name string = 'uami-Runner-${Environment}-${location}'
param ContainerRegistry_Name string = toLower('acr${Environment}${guid_pattern}')
param LogAnalytics_Workspace_Name string = toLower('law-Runner-${Environment}-${location}')
param LogAnalytics_Workspace_RetentionInDays int = 30

param VirtualNetwork_Name string = 'vnet-Runner-${Environment}-${location}'
param VirtualNetwork_Prefix string = '10.0.0.0/16'
param ACA_DedicatedSubnet string = 'subnet-aca'
param ACA_DedicatedSubnet_Prefix string = '10.0.0.0/24'

param param_guid string = 'ab2cae52-3be6-4eca-87bf-3f71eb825aef'
param guid_pattern string = replace(substring(param_guid, 0, 12), '-', '')
param KeyVault_Name string = toLower('kv-${Environment}-${guid_pattern}')

param uami_keyvault_secrets_user_guid string = 'd86a3f1e-2d4f-4f12-8a6a-6f2b1e5e3c3b'
param uami_keyvault_secrets_officer_guid string = 'fb382eab-e894-4461-af04-94435c366c3f'
param uami_keyvault_access_policies_guid string = 'fb382eab-e894-4461-af04-94435c366c3f'

// Tags to be set on all resources
var tags = {
  Project: 'GitHub Runners on Container Apps'
  Environment: Environment
  version: '0.1'
}
// Resource group for all resources related to the solution
targetScope = 'subscription'
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: ResourceGroup_Name
  location: location
  tags: tags
}

// User assigned identity to be used to pull image & cess secrets in Key Vault
// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/managed-identity/user-assigned-identity
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${uniqueString(deployment().name, location)}-aca-uami'
  scope: rg
  params: {
    name: User_Assigned_Identity_Name
    location: location
    tags: tags
    enableTelemetry: true
  }
}
// Log Analytics Workspace for Container Apps diagnostics
// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/operational-insights/workspace
module workspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: '${uniqueString(deployment().name, location)}-law'
  scope: rg
  params: {
    name: LogAnalytics_Workspace_Name
    location: location
    dataRetention: LogAnalytics_Workspace_RetentionInDays
    skuName: 'PerGB2018'
    enableTelemetry: true
    tags: tags
  }
}
// Container Registry to store GitHub Runner container image
// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/container-registry/registry
module registry 'br/public:avm/res/container-registry/registry:0.9.3' = {
  name: '${uniqueString(deployment().name, location)}-acr'
  scope: rg
  params: {
    name: ContainerRegistry_Name
    acrSku: 'Basic'
    acrAdminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    location: location
    tags: tags
    cacheRules: [
      {
        name: 'actions-runner'
        sourceRepository: 'ghcr.io/actions/actions-runner'
      }
    ]
    diagnosticSettings: [
      {
        name: 'acr-diagnostics'
        workspaceResourceId: workspace.outputs.resourceId
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ]
    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'AcrPull'
      }
      {
        principalId: deployer().objectId
        roleDefinitionIdOrName: 'AcrPush'
      }
    ]
  }
}
// Virtual Network to be used by Container Apps environment
// source : https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/virtual-network
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: '${uniqueString(deployment().name, location)}-vnet'
  scope: rg
  params: {
    name: VirtualNetwork_Name
    addressPrefixes: [VirtualNetwork_Prefix]
    location: location
    subnets: [
      {
        addressPrefix: ACA_DedicatedSubnet_Prefix
        name: ACA_DedicatedSubnet
        delegation: 'Microsoft.App/environments'
      }
    ]
    tags: tags
    diagnosticSettings: [
      {
        name: 'vnet-diagnostics'
        workspaceResourceId: workspace.outputs.resourceId
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ]
    enableTelemetry: true
  }
}

// Key Vault to be used by the solution to store secrets
// issue with role assignment, because already exists (https://j4ni.com/blog/2025/05/20/bicep-onlyifnotexists/)
// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/key-vault/vault
//@onlyIfNotExists()

module KeyVault 'br/public:avm/res/key-vault/vault:0.13.3' = {
  scope: rg
  name: '${uniqueString(deployment().name, location)}-kv'
  params: {
    name: KeyVault_Name
    tags: tags
    sku: 'standard'
    enablePurgeProtection: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    secrets: []
    // issue with role assignment, because already exists
    roleAssignments: [
      {
        name: uami_keyvault_secrets_user_guid
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
        description: 'Allows the UAMI to read secrets from the Key Vault'
      }
      {
        name: uami_keyvault_secrets_officer_guid
        principalId: deployer().objectId
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        description: 'Allows the deployer to manage secrets in the Key Vault'
      }
      {
        name: uami_keyvault_access_policies_guid
        principalId: deployer().objectId
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/fb382eab-e894-4461-af04-94435c366c3f'
        description: 'Allows the deployer to manage Key Vault access policies'
      }
    ]
  }
}
