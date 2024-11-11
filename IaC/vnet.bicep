// inputs : https://github.com/mddazure/azure_verified_module_lab/blob/main/main.bicep

// input projet avec les infos de VNET / Subnet et   infrastructureSubnetId:  pour ACA

@description('Azure region in witch solution will be deployed')
param param_location string = 'westeurope'

@description('name of the environment to be used as prefix for azure resources')
param param_environment_name string = 'nprd'

@description('Project name ')
param param_project_name string = 'acarunner'

@description('Project version')
param param_project_version string = '1.0'

@description('VNET address prefix')
param param_solution_vnet_addressprefix string = '10.0.0.0/16'

@description('Subnet CIRD to be dedicated for Azure Container Apps environment')
param param_solution_subnet_prefix string = '10.0.0.0/23'

@description('The GitHub Access Token with permission to fetch registration-token')
@secure()
param param_GitHubAccessToken string = 'test'

param param_guid string = newGuid()

//
// Variable section
//
var varSecretNameGitHubAccessToken = 'github-accesstoken'
var var_Solution_vnet_name = '${param_environment_name}-${param_project_name}-vnet'
var var_Solution_aca_environment_name = '${param_environment_name}--${param_project_name}-acaenv'
var var_param_law_name = '${param_environment_name}-${param_project_name}-law'
var var_userAssignedIdentity_name = '${param_environment_name}-${param_project_name}-uai'
var var_guid_pattern = replace(substring(param_guid, 0, 12), '-', '')
var var_kv_name = 'kv${var_guid_pattern}'
var var_acr_name = 'acr${param_environment_name}${var_guid_pattern}'
var var_solution_rg_name = 'RG-${param_environment_name}-${param_project_name}-${param_project_version}'
var var_managedEnvironment_param_rg_name = 'RG-${param_environment_name}-${param_project_name}-${param_project_version}-acaenv'
var var_aca_dedicated_subnet_name = 'aca'
var var_project_tags = {
  Project: param_project_name
  Environment: param_environment_name
  version: param_project_version
}
// Resource group for all resources related to the solution
targetScope = 'subscription'
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: var_solution_rg_name
  location: param_location
  tags: var_project_tags
}
// Key Vault to be used by the solution to store secrets
module KeyVault 'br/public:avm/res/key-vault/vault:0.10.2' = {
  scope: rg
  name: '${uniqueString(deployment().name, param_location)}-kv'
  params: {
    name: var_kv_name
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
// Virtual Network to be used by Container Apps environment
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: '${uniqueString(deployment().name, param_location)}-vnet'
  scope: rg
  params: {
    name: var_Solution_vnet_name
    //addressPrefixes: ['10.0.0.0/16']
    addressPrefixes: [
      param_solution_vnet_addressprefix
    ]
    location: param_location
    tags: var_project_tags
    subnets: [
      {
        //        addressPrefix: '10.0.0.0/23'
        addressPrefix: param_solution_subnet_prefix
        name: var_aca_dedicated_subnet_name
        delegation: 'Microsoft.App/environments'
      }
    ]
  }
}
// Log Analytics workspace to be used in the solution
module workspace 'br/public:avm/res/operational-insights/workspace:0.7.1' = {
  name: '${uniqueString(deployment().name, param_location)}-law'
  scope: rg
  params: {
    name: var_param_law_name
    location: param_location
    tags: var_project_tags
  }
}
// User assigned identity to be used to pull image & cess secrets in Key Vault
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${uniqueString(deployment().name, param_location)}-aca-uami'
  scope: rg
  params: {
    name: var_userAssignedIdentity_name
    location: param_location
    tags: var_project_tags
  }
}
// Azure container registry with ACR pull role asignment
// Note, pas de privatisation car problème oeuf et de la poule
module registry 'br/public:avm/res/container-registry/registry:0.6.0' = {
  name: '${uniqueString(deployment().name, param_location)}-acr'
  scope: rg
  dependsOn: [
    userAssignedIdentity
  ]
  params: {
    // name: param_acr_name
    name: var_acr_name
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
    infrastructureResourceGroupName: var_managedEnvironment_param_rg_name
    infrastructureSubnetId: '${virtualNetwork.outputs.resourceId}/subnets/${var_aca_dedicated_subnet_name}'
    tags: var_project_tags
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
output output_ky_name string = var_kv_name
output output_acr_name string = var_acr_name
// maintenant, il faut créer l'image Docker
// prochaine étape, la condtruction du job
// etape finale : créer le workflow
