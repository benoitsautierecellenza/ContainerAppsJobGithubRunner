//az deployment group create --resource-group rg-Runner-DEV-westeurope --template-file GitHubRunner-job.bicep

@description('Azure region in which solution will be deployed')
param location string = 'westeurope'

@description('environment name')
param Environment string = 'DEV'

@description('Azure Container Registry name')
param Acr_Name string = 'devdacr1'

@description('Azure Key Vault name')
param KeyVault_Name string = 'kvab2cae523be'

@description('GITHUB Image version')
param Runner_Image_Tag string = '2.239.0' 

@description('GitHub repository owner')
param GitHub_Repo_Owner string = 'benoitsautierecellenza'

@description('GitHub repository name')
param GitHub_Repo_Name string = 'containerappsjobgithubrunner'

@description('GitHub App ID')
param GitHub_App_ID string = '1643445' // new GitHub App dedicated to Runner

@description('GitHub App Installation ID')
param GitHub_App_Installation_ID int = 76950829 // new GitHub App dedicated to Runner

@description('Project version')
param Version string = '0.1'

var CONTAINER_APP_ENV_NAME = '${Environment}-${location}-acaenv'
var VAR_USERASSIGNEDIDENTITY_NAME = 'uami-Runner-${Environment}-${location}'
var ACR_LOGINSERVER = '${Acr_Name}.azurecr.io' 
var GitHub_Runner_Job_Name = 'githubactionrunner'
var GitHub_Runner_Image_Name = 'runner_base'
var GitHub_Runner_Scope = 'repo'
var GITHUB_PRM_SECRET = 'GitHubPEM'
var GITHUB_RUNNER_IMAGE_PATH = '${ACR_LOGINSERVER}/${GitHub_Runner_Image_Name}:${Runner_Image_Tag}' 
var ACCESS_TOKEN_API_URL = 'https://api.github.com/app/installations/${GitHub_App_Installation_ID}/access_tokens' 
var GITHUB_REGISTRATION_TOKEN_API_URL = 'https://api.github.com/repos/${GitHub_Repo_Owner}/${GitHub_Repo_Name}/actions/runners/registration-token' 
var GITHUB_RUNNER_REGISTRATION_URL = 'https://github.com/${GitHub_Repo_Owner}/${GitHub_Repo_Name}' 
var tags = {
  Project: 'GitHub Runners on Container Apps'
  Environment: Environment
  version: Version
}
// pre-existing resources
// User-Assigned managed identity to be used by the Container Apps Job
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = { name: VAR_USERASSIGNEDIDENTITY_NAME }
// Azure Container Apps environment previously deployed
resource ContainerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = { name: CONTAINER_APP_ENV_NAME}
// Resource Azure Container Registry previously deployed
resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = { name: Acr_Name }
// Resource Azure Key Vault previously deployed
resource kv 'Microsoft.KeyVault/vaults@2024-12-01-preview' existing = { name: KeyVault_Name }
// secret must be uploaded in Key Vault beforehand
resource kv_secret 'Microsoft.KeyVault/vaults/secrets@2024-12-01-preview' existing = {
  name: GITHUB_PRM_SECRET
  parent: kv
}
// azure Container Apps Job
// source : https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/app/job
module acj 'br/public:avm/res/app/job:0.7.1' = {
  name: '${uniqueString(deployment().name, location)}-acj'
  params: {
    name: GitHub_Runner_Job_Name
    tags: tags
    environmentResourceId: ContainerAppsEnvironment.id
    containers: [
      {
        name: GitHub_Runner_Job_Name
        image: GITHUB_RUNNER_IMAGE_PATH
        resources: {
          cpu: '1.0'
          memory: '2.0Gi'
        }
        env: [
          { name: 'PEM', secretRef: 'pem' }
          { name: 'APP_ID', value: GitHub_App_ID }
          { name: 'ACCESS_TOKEN_API_URL', value: ACCESS_TOKEN_API_URL }
          { name: 'RUNNER_REGISTRATION_URL', value: GITHUB_RUNNER_REGISTRATION_URL }
          { name: 'REGISTRATION_TOKEN_API_URL', value: GITHUB_REGISTRATION_TOKEN_API_URL }
        ]
      }
    ]
    secrets: [
      {
        name: 'pem'
        keyVaultUrl: kv_secret.properties.secretUri
        identity: userAssignedIdentity.id // Use the resource ID for the identity
      }
    ]
    registries: [
      {
        server: acr.properties.loginServer
        identity: userAssignedIdentity.id // Use the resource ID for the identity
      }
    ]
    triggerType: 'Event'
    eventTriggerConfig: {
      scale: {
        rules: [
          {
            name: 'github-runner-scaling-rule'
            type: 'github-runner'
            auth: [
              {
                triggerParameter: 'appKey'
                secretRef: 'pem'
              }
            ]
            metadata: {
              owner: GitHub_Repo_Owner
              repos: GitHub_Repo_Name
              runnerScope: GitHub_Runner_Scope
              targetWorkflowQueueLength: '1'
              applicationID: GitHub_App_ID
              installationID: GitHub_App_Installation_ID
            }
          }
        ]
      }
    }
    managedIdentities: {
      userAssignedResourceIds: [userAssignedIdentity.id] // Use the resource ID for the managed identity
    }
  }
}
