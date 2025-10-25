param location string = 'westeurope'
param acrName string = 'devdacr1'
param Environment string = 'DEV'
param ghRunnerImageVersion string = '2.329.0'
param githubRepoOwner string = 'benoitsautierecellenza'
param githubRepoName string = 'ContainerAppsJobGithubRunner'

param ResourceGroup_Name string = 'rg-Runner-${Environment}-${location}'
param LogAnalytics_Workspace_Name string = 'law-Runner-${Environment}-${location}'
param LogAnalytics_Workspace_RetentionInDays int = 30
param User_Assigned_Identity_Name string = 'uami-Runner-${Environment}-${location}'
param VirtualNetwork_Name string = 'vnet-Runner-${Environment}-${location}'
param VirtualNetwork_Prefix string = '10.0.0.0/16'
param ACA_DedicatedSubnet string= 'subnet-aca'

param param_guid string = 'ab2cae52-3be6-4eca-87bf-3f71eb825aef'
param guid_pattern string = replace(substring(param_guid, 0, 12), '-', '')
param ContainerRegistry_Name string = 'acr${Environment}${guid_pattern}'
// Tags to be set on all resources
var tags = {
  Project: 'GitHub Runners on Container Apps'
  Environment: Environment
  version: '0.1'
}
// Resource group for all resources related to the solution
module resourceGroup 'br/public:avm/res/resources/resource-group:0.4.2' = {
  scope: subscription()
  name: 'resourceGroupDeployment'
  params: {
    name: ResourceGroup_Name
    location: location
    tags: tags
  }
}
// User assigned identity to be used to pull image & cess secrets in Key Vault
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${uniqueString(deployment().name, location)}-aca-uami'
  scope: resourceGroup
  params: {
    name: User_Assigned_Identity_Name
    location: location
    enableTelemetry: true
    tags: tags
  }
}
// Key Vault to be used by the solution to store secrets
// unicity problem to be solved
module KeyVault 'br/public:avm/res/key-vault/vault:0.10.2' = {
  scope: rg
  name: '${uniqueString(deployment().name, location)}-kv'
  params: {
    name: VAR_KEYVAULT_NAME
    tags: tags
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
  name: '${uniqueString(deployment().name, location)}-vnet'
  scope: rg
  params: {
    name: VirtualNetwork_Name
    addressPrefixes: [VirtualNetwork_Prefix]
    location: location
    subnets: [
      {
        addressPrefix: PARAM_SOLUTION_SUBNET_PREFIX
        name: ACA_DedicatedSubnet
        delegation: 'Microsoft.App/environments'
      }
    ]
    tags: tags
  }
}
// Dedicated Log Analytics workspace for the solution
module workspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: '${uniqueString(deployment().name, location)}-law'
  scope: rg
  params: {
    // Required parameters
    name: LogAnalytics_Workspace_Name
    // Non-required parameters
    location: location
    dataRetention: LogAnalytics_Workspace_RetentionInDays
    skuName: 'PerGB2018'
    enableTelemetry:true
    tags: tags
  }
}
// Azure container registry with ACR with pull role assignment for User assigned identity
// Add rule cache for required images
module registry 'br/public:avm/res/container-registry/registry:0.6.0' = {
  name: '${uniqueString(deployment().name, location)}-acr'
  scope: rg
  params: {
    name: ContainerRegistry_Name
    acrSku: 'Basic'
    location: location
    tags: tags
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
// input : https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/dev-ops/cicd-agents-and-runners#example-3-using-only-defaults-for-github-self-hosted-runners-using-azure-container-apps
module cicdAgentsAndRunners 'br/public:avm/ptn/dev-ops/cicd-agents-and-runners:0.3.1' = {
  name: 'deployCICDAgentsAndRunners'
  params: {
    computeTypes: [
      'azure-container-app'
    ]
    namingPrefix: Environment
    networkingConfiguration: 'useExisting'
    infrastructureResourceGroupName: 'rg-${Environment}-Runner-${location}'
    solutionEnvironmentName: solutionEnvironmentName
    location: location
    acrName: acrName
    ghRunnerImageVersion: ghRunnerImageVersion
    githubRepoOwner: githubRepoOwner
    githubRepoName: githubRepoName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    logAnalyticsWorkspaceKey: logAnalyticsWorkspaceKey
    vnetId: vnetId
    subnetId: subnetId
    tags: tags
    enableTelemetry: true
  }
}
