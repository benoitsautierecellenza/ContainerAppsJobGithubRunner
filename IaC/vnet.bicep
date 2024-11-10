// inputs : https://github.com/mddazure/azure_verified_module_lab/blob/main/main.bicep
@description('Resource Group name to deploy the complete solution')
param param_rg_name string = 'demo'

// input projet avec les infos de VNET / Subnet et   infrastructureSubnetId:  pour ACA

@description('Azure region in witch solution will be deployed')
param param_location string = 'westeurope'

@description('name of the environment to be used as prefix for azure resources')
param param_environment_name string = 'nprd'

@description('Project name ')
param param_project_name string = 'acarunner'

@description('Project version')
param param_project_version string = '1.0'

@description('Virtual Network name to be used by the solution')
param param_vnet_name string = 'demovnet'

@description('Log Analytics workspace to be used by the solution.')
param param_law_name string = 'demolaw'

@description('Key Vault name to be used by the solution')
param param_kv_name string = 'demols9678678'

@description('The GitHub Access Token with permission to fetch registration-token')
@secure()
param param_GitHubAccessToken string = 'test'

@description('Azure Container registry name')
param param_acr_name string = 'demoacr978945'

@description('Azure User-Assiged Managed identity to be use dby the solution')
param param_userAssignedIdentity_name string = 'identity'

@description('Azure Container Apps environment to be created')
param param_managedEnvironment_name string = 'aca'

@description('Managed resource group name for ACA')
param param_managedEnvironment_param_rg_name string = 'RG_ACA'

//
// Variable section
//
var varSecretNameGitHubAccessToken = 'github-accesstoken'
var var_Solution_vnet_name = '${param_environment_name}-vnet'
var var_Solution_aca_environment_name = '${param_environment_name}-aca-env'
var var_param_law_name = '${param_environment_name}-law'
var var_userAssignedIdentity_name = '${param_environment_name}-${param_project_name}-law'
// possible randomizer le container registry name?

var var_project_tags = {
  Project: param_project_name
  Environment: param_environment_name
  version: param_project_version
}

targetScope = 'subscription'
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: param_rg_name
  location: param_location
  tags: var_project_tags
}
// Provisioned Key Vault with secret
module KeyVault 'br/public:avm/res/key-vault/vault:0.10.2' = {
  scope: rg
  name: '${uniqueString(deployment().name, param_location)}-kv'
  params: {
    name: param_kv_name
    tags: var_project_tags
    sku: 'standard'
    enablePurgeProtection: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    secrets: [
      {
        name: varSecretNameGitHubAccessToken
        value: param_GitHubAccessToken
      }
    ]
    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ]
  }
}
// Virtual Network to be used by Container Apps
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: '${uniqueString(deployment().name, param_location)}-vnet'
  scope: rg
  params: {
    name: var_Solution_vnet_name
    //name: param_vnet_name
    addressPrefixes: ['10.0.0.0/16']
    location: param_location
    tags: var_project_tags
    subnets: [
      {
        addressPrefix: '10.0.0.0/23'
        name: 'aca'
        delegation: 'Microsoft.App/environments'
      }
    ]
  }
}
// Log Analytics workspace required for Container Apps
module workspace 'br/public:avm/res/operational-insights/workspace:0.7.1' = {
  name: '${uniqueString(deployment().name, param_location)}-law'
  scope: rg
  params: {
    name: var_param_law_name
    //  name: param_law_name
    location: param_location
    tags: var_project_tags
  }
}
// User assigned identity to be used to pull image & cess secrets in Key Vault
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${uniqueString(deployment().name, param_location)}-aca-uami'
  scope: rg
  params: {
    //name: param_userAssignedIdentity_name
    name: var_userAssignedIdentity_name
    location: param_location
    tags: var_project_tags
  }
}
// Azure container registry with ACR pull role asignment
module registry 'br/public:avm/res/container-registry/registry:0.6.0' = {
  name: '${uniqueString(deployment().name, param_location)}-acr'
  scope: rg
  dependsOn: [
    userAssignedIdentity
  ]
  params: {
    name: param_acr_name
    acrSku: 'Basic'
    location: param_location
    tags: var_project_tags
    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'AcrPull'
      }
    ]
  }
}
// besoin de ce paramètre : https://github.com/Azure/bicep-registry-modules/blob/avm/res/app/managed-environment/0.8.1/avm/res/app/managed-environment/README.md#parameter-managedidentities
module ACAmanagedEnv 'br/public:avm/res/app/managed-environment:0.8.1' = {
  scope: rg
  name: '${uniqueString(deployment().name, param_location)}-ACA-managed-environment'
  params: {
    name: var_Solution_aca_environment_name
    logAnalyticsWorkspaceResourceId: workspace.outputs.resourceId
    infrastructureResourceGroupName: param_managedEnvironment_param_rg_name
    infrastructureSubnetId: '${virtualNetwork.outputs.resourceId}/subnets/aca'
    tags: var_project_tags
    internal: true
    zoneRedundant: false
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}
// maintenant, il faut créer l'image Docker
// prochaine étape, la condtruction du job
// etape finale : créer le workflow
