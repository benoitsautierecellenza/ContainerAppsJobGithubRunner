// az deployment sub create --location westeurope --template-file runner-environment.bicep
@description('Azure region in which solution will be deployed')
param location string = 'westeurope'

@description('Name of the environment')
param Environment string = 'DEV'

@description('Log Analytics Workspace retention in days')
param LogAnalytics_Workspace_RetentionInDays int = 30

@description('Virtual Network address space prefix')
param VirtualNetwork_Prefix string = '10.0.0.0/16'

@description('Azure Container Apps dedicated subnet name')
param ACA_DedicatedSubnet_Prefix string = '10.0.0.0/24'

@description('Project version')
param Version string = '0.1'
// variables
var ResourceGroup_Name = 'rg-Runner-${Environment}-${location}'
var User_Assigned_Identity_Name = 'uami-Runner-${Environment}-${location}'
var ContainerRegistry_Name = toLower('acr${Environment}${guid_pattern}')
var LogAnalytics_Workspace_Name = toLower('law-Runner-${Environment}-${location}')
var ApplicationInsights_Name = 'appi-Runner-${Environment}-${location}'
var ContainerAppsEnvironment_Name = '${Environment}-${location}-acaenv'
var ContainerAppsEnvironment_RG_Name = 'rg-acaenv-${Environment}-${location}'
var VirtualNetwork_Name = 'vnet-Runner-${Environment}-${location}'
var ACA_DedicatedSubnet  = 'subnet-aca'
var param_guid  = 'ab2cae52-3be6-4eca-87bf-3f71eb825aef'
var guid_pattern  = replace(substring(param_guid, 0, 12), '-', '')
var uami_keyvault_secrets_user_guid = 'd86a3f1e-2d4f-4f12-8a6a-6f2b1e5e3c3b' 
var uami_keyvault_secrets_officer_guid = 'fb382eab-e894-4461-af04-94435c366c3f' 
var uami_keyvault_access_policies_guid = 'fb382eab-e894-4461-af04-94435c366c3e' 
var KeyVault_Name = toLower('kv0-${Environment}-${guid_pattern}')
var tags = {
  Project: 'GitHub Runners on Container Apps'
  Environment: Environment
  version: Version
}
// resources
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
// source : https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/operational-insights/workspace
module workspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: '${uniqueString(deployment().name, location)}-law'
  scope: rg
  params: {
    name: LogAnalytics_Workspace_Name
    location: location
    dataRetention: LogAnalytics_Workspace_RetentionInDays
    skuName: 'PerGB2018'
    tags: tags
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    enableTelemetry: true
  }
}
// Application Insights
// source : https://github.com/Azure/bicep-registry-modules/blob/main/avm/res/insights/component/README.md
module component 'br/public:avm/res/insights/component:0.6.1' = {
  name: '${uniqueString(deployment().name, location)}-insights'
  scope: rg
  params: {
    name: ApplicationInsights_Name
    workspaceResourceId: workspace.outputs.resourceId
    location: location
    tags: tags
    applicationType: 'web'
    enableTelemetry: true
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
// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/key-vault/vault
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
    roleAssignments: [
      {
        name: uami_keyvault_secrets_user_guid // enforce stable GUID for role assignment idempotency
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
        description: 'Allows the UAMI to read secrets from the Key Vault'
      }
      {
        name: uami_keyvault_secrets_officer_guid // enforce stable GUID for role assignment idempotency
        principalId: deployer().objectId
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        description: 'Allows the deployer to manage secrets in the Key Vault'
      }
      {
        name: uami_keyvault_access_policies_guid // enforce stable GUID for role assignment idempotency
        principalId: deployer().objectId
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/fb382eab-e894-4461-af04-94435c366c3f'
        description: 'Allows the deployer to manage Key Vault access policies'
      }
    ]
  }
}
// Azure Container Apps Managed Environment to host the GitHub Runners
// source : https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/app/managed-environment
module ACAmanagedEnv 'br/public:avm/res/app/managed-environment:0.11.3' = {
  scope: rg
  name: '${uniqueString(deployment().name, location)}-ACAEnv'
  params: {
    name: ContainerAppsEnvironment_Name
    infrastructureResourceGroupName: ContainerAppsEnvironment_RG_Name
    infrastructureSubnetResourceId: '${virtualNetwork.outputs.resourceId}/subnets/${ACA_DedicatedSubnet}'
    tags: tags
    internal: true
    zoneRedundant: false
    managedIdentities: {
      userAssignedResourceIds: [
        userAssignedIdentity.outputs.resourceId
      ]
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.outputs.logAnalyticsWorkspaceId
        sharedKey: workspace.outputs.primarySharedKey
      }
    }
    appInsightsConnectionString : component.outputs.connectionString
    enableTelemetry: true
  }
}
