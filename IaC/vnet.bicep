// inputs : https://github.com/mddazure/azure_verified_module_lab/blob/main/main.bicep
param rg_name string = 'demo'
param location string = 'westeurope'
param vnet_name string = 'demovnet'
param law_name string = 'demolaw'
param managedEnvironment_name string = 'aca'
param managedEnvironment_rg_name string = 'RG_ACA'
param acr_name string ='demoacr9789'
param userAssignedIdentity_name string = 'identity'
param project_tags object = {
  Dept: 'Cellenza'
  Environment: 'demo'
  Lifecycle: 'short' 
}
targetScope = 'subscription'
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg_name
  location: location
  tags: project_tags
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'virtualNetworkDeployment'
  scope: rg
  params: {
    name: vnet_name
    addressPrefixes: ['10.0.0.0/16']
    location: location
    tags: project_tags
    subnets: [
      {
        addressPrefix: '10.0.0.0/23'
        name: 'aca'
      }
    ]
  }
}
module workspace 'br/public:avm/res/operational-insights/workspace:0.7.1' = {
  name: 'workspaceDeployment'
  scope: rg
  params: {
    name: law_name
    location: location
    tags: project_tags
  }
}
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'userAssignedIdentityDeployment'
  scope: rg
  params: {
    name: userAssignedIdentity_name
    location: location
  }
}
//not yet functionnal
// inputs : https://gist.github.com/jornbeyers/39e56ac1435c351acb111f6a3ac91faa
// all detailed : https://blog.eula.no/posts/github-runners-self-hosted-part-2/
module managedEnvironment 'br/public:avm/res/app/managed-environment:0.8.1' = {
  name: 'managedEnvironmentDeployment'
  dependsOn: [
    virtualNetwork
    userAssignedIdentity
  ]
  scope: rg
  params: {
    logAnalyticsWorkspaceResourceId: workspace.outputs.resourceId
    name: managedEnvironment_name
    dockerBridgeCidr: '172.16.0.1/28'
    infrastructureResourceGroupName: managedEnvironment_rg_name
    infrastructureSubnetId: '${virtualNetwork.outputs.resourceId}/subnets/aca'    
    internal: true
    location: location
    tags: project_tags
    platformReservedCidr: '172.17.17.0/24'
    platformReservedDnsIP: '172.17.17.17'
  }
}
module registry 'br/public:avm/res/container-registry/registry:0.6.0' = {
  name: 'registryDeployment'
  scope: rg
  dependsOn: [
    userAssignedIdentity
  ]
  params: {
    name: acr_name
    acrSku: 'Basic'
    location: location
    tags: project_tags
  }
}
// role assignment for image pull
