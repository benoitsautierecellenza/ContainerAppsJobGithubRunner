
@description('Azure region in witch solution will be deployed')
param PARAM_LOCATION string = 'westeurope'

@description('name of the environment to be used as prefix for azure resources')
param PARAM_ENVIRONMENT_NAME string = 'nprd'

@description('Project name ')
param PARAM_PROJECT_NAME string = 'acarunner'

@description('Project version')
param PARAM_PROJECT_VERSION string = '1.0'

@description('VNET address prefix')
param PARAM_SOLUTION_VNET_ADDRESSPREFIX string = '10.0.0.0/16'

@description('Subnet CIRD to be dedicated for Azure Container Apps environment')
param PARAM_SOLUTION_SUBNET_PREFIX string = '10.0.0.0/23'

// En fait, j'ai un GUID à chaque exécution
//param param_guid string = newGuid()
param param_guid string = 'ab2cae52-3be6-4eca-87bf-3f71eb825aef'

//
// Variable section
//
var VAR_SOLUTION_VNET_NAME = '${PARAM_ENVIRONMENT_NAME}-${PARAM_PROJECT_NAME}-vnet'
var VAR_SOLUTION_ACA_ENVIRONMENT_NAME = '${PARAM_ENVIRONMENT_NAME}-${PARAM_PROJECT_NAME}-acaenv' // fix name for the Container Apps environment
var VAR_LAW_NAME = '${PARAM_ENVIRONMENT_NAME}-${PARAM_PROJECT_NAME}-law'
var VAR_USERASSIGNEDIDENTITY_NAME = '${PARAM_ENVIRONMENT_NAME}-${PARAM_PROJECT_NAME}-uai'
var var_guid_pattern = replace(substring(param_guid, 0, 12), '-', '')
var VAR_KEYVAULT_NAME = 'kv${var_guid_pattern}'
var VAR_ACR_NAME = 'acr${PARAM_ENVIRONMENT_NAME}${var_guid_pattern}'
var VAR_SOLUTION_RG_NAME = 'RG-${PARAM_ENVIRONMENT_NAME}-${PARAM_PROJECT_NAME}-${PARAM_PROJECT_VERSION}'
var VAR_ACA_MANAGEDRG_NAME = 'RG-${PARAM_ENVIRONMENT_NAME}-${PARAM_PROJECT_NAME}-${PARAM_PROJECT_VERSION}-acaenv'
var VAR_ACA_SUBNET_NAME = 'aca'
var VAR_SOLUTION_TAGS = {
  Project: PARAM_PROJECT_NAME
  Environment: PARAM_ENVIRONMENT_NAME
  version: PARAM_PROJECT_VERSION
}
// Resource group for all resources related to the solution
targetScope = 'subscription'
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: VAR_SOLUTION_RG_NAME
  location: PARAM_LOCATION
  tags: VAR_SOLUTION_TAGS
}
// Key Vault to be used by the solution to store secrets
module KeyVault 'br/public:avm/res/key-vault/vault:0.10.2' = {
  scope: rg
  name: '${uniqueString(deployment().name, PARAM_LOCATION)}-kv'
  params: {
    name: VAR_KEYVAULT_NAME
    tags: VAR_SOLUTION_TAGS
    sku: 'standard'
    enablePurgeProtection: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    secrets: []
    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
      {
        principalId: deployer().objectId
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
      }
      {
        principalId: deployer().objectId
        roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/fb382eab-e894-4461-af04-94435c366c3f'
      }
    ]
  }
}
// Virtual Network to be used by Container Apps environment
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: '${uniqueString(deployment().name, PARAM_LOCATION)}-vnet'
  scope: rg
  params: {
    name: VAR_SOLUTION_VNET_NAME
    addressPrefixes: [
      PARAM_SOLUTION_VNET_ADDRESSPREFIX
    ]
    location: PARAM_LOCATION
    tags: VAR_SOLUTION_TAGS
    subnets: [
      {
        addressPrefix: PARAM_SOLUTION_SUBNET_PREFIX
        name: VAR_ACA_SUBNET_NAME
        delegation: 'Microsoft.App/environments'
      }
    ]
  }
}
// Log Analytics workspace to be used in the solution
module workspace 'br/public:avm/res/operational-insights/workspace:0.7.1' = {
  name: '${uniqueString(deployment().name, PARAM_LOCATION)}-law'
  scope: rg
  params: {
    name: VAR_LAW_NAME
    location: PARAM_LOCATION
    tags: VAR_SOLUTION_TAGS
    dailyQuotaGb:5
    dataRetention: 30
    skuName: 'PerGB2018'   
  }
}
// User assigned identity to be used to pull image & cess secrets in Key Vault
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${uniqueString(deployment().name, PARAM_LOCATION)}-aca-uami'
  scope: rg
  params: {
    name: VAR_USERASSIGNEDIDENTITY_NAME
    location: PARAM_LOCATION
    tags: VAR_SOLUTION_TAGS
  }
}
// Azure container registry with ACR pull role asignment
module registry 'br/public:avm/res/container-registry/registry:0.6.0' = {
  name: '${uniqueString(deployment().name, PARAM_LOCATION)}-acr'
  scope: rg
  params: {
    name: VAR_ACR_NAME
    acrSku: 'Basic'
    location: PARAM_LOCATION
    tags: VAR_SOLUTION_TAGS
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
// conditional deployment of the Azure Container Apps environment (to be developped)
//@onlyIfNotExists()
module ACAmanagedEnv 'br/public:avm/res/app/managed-environment:0.8.1' = {
  scope: rg
  name: '${uniqueString(deployment().name, PARAM_LOCATION)}-ACA-managed-environment'
  params: {
    name: VAR_SOLUTION_ACA_ENVIRONMENT_NAME
    logAnalyticsWorkspaceResourceId: workspace.outputs.resourceId
    infrastructureResourceGroupName: VAR_ACA_MANAGEDRG_NAME
    infrastructureSubnetId: '${virtualNetwork.outputs.resourceId}/subnets/${VAR_ACA_SUBNET_NAME}'
    tags: VAR_SOLUTION_TAGS
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
  }
}
output output_ky_name string = VAR_KEYVAULT_NAME
output output_acr_name string = VAR_ACR_NAME
