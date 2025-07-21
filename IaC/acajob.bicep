@description('Project name ')
param PARAM_PROJECT_NAME string = 'acarunner'

@description('name of the environment to be used as prefix for azure resources')
param PARAM_PROJECT_VERSION string = '1.0'

@description('Azure region in which solution will be deployed')
param PARAM_LOCATION string = 'westeurope'

@description('Project version')
param ENVIRONMENT_NAME string = 'nprd'

@description('Azure Container Registry name')
param ACR_NAME string = 'acrnprdab2cae523be'

@description('Azure Key Vault name')
param KEYVAULT_NAME string = 'kvab2cae523be'

@description('GITHUB Image version')
param RUNNER_IMAGE_VERSION string = '2.325.0' // Remplacer par '2.325.0' quand on veut utiliser la dernière version

@description('GitHub repository owner')
param GITHUB_REPO_OWNER string = 'benoitsautierecellenza'

@description('GitHub repository name')
param GITHUB_REPO_NAME string = 'containerappsjobgithubrunner'

@description('GitHub App ID')
param GITHUB_APP_ID string = '1643445'

@description('GitHub App Installation ID')
param GITHUB_APP_INSTALLATION_ID int = 76950829

var CONTAINER_APP_ENV_NAME = '${ENVIRONMENT_NAME}-${PARAM_PROJECT_NAME}-acaenv'
var VAR_USERASSIGNEDIDENTITY_NAME = '${ENVIRONMENT_NAME}-${PARAM_PROJECT_NAME}-uai' 
var ACR_LOGINSERVER = '${ACR_NAME}.azurecr.io' 
var GITHUB_RUNNER_JOB_NAME = 'githubactionrunner'
var GITHUB_RUNNER_IMAGE_NAME = 'runner_base'
var GITHUB_RUNNER_SCOPE = 'repo'
var GITHUB_PRM_SECRET = 'GitHubPEM'
var GITHUB_RUNNER_IMAGE_PATH = '${ACR_LOGINSERVER}/${GITHUB_RUNNER_IMAGE_NAME}:${RUNNER_IMAGE_VERSION}' 
var ACCESS_TOKEN_API_URL = 'https://api.github.com/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens' 
var GITHUB_REGISTRATION_TOKEN_API_URL = 'https://api.github.com/repos/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/actions/runners/registration-token' 
var GITHUB_RUNNER_REGISTRATION_URL = 'https://github.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}' 

// existing user assigned identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: VAR_USERASSIGNEDIDENTITY_NAME
}
// resource Azure Container Apps environment
resource ContainerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = {
  name: CONTAINER_APP_ENV_NAME
}
// resource Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = { name: ACR_NAME }
// resource Key Vault
resource kv 'Microsoft.KeyVault/vaults@2024-12-01-preview' existing = { name: KEYVAULT_NAME }
resource kv_secret 'Microsoft.KeyVault/vaults/secrets@2024-12-01-preview' existing = {
  name: GITHUB_PRM_SECRET
  parent: kv
}

module acj 'br/public:avm/res/app/job:0.6.0' = {
  name: '${uniqueString(deployment().name, PARAM_LOCATION)}-acj'

  params: {
    name: GITHUB_RUNNER_JOB_NAME
    tags: {
      Project: PARAM_PROJECT_NAME
      Environment: ENVIRONMENT_NAME
      version: PARAM_PROJECT_VERSION
    }
    //environmentResourceId: ContainerAppsEnvironment.outputs.resourceId
    environmentResourceId: ContainerAppsEnvironment.id
    containers: [
      {
        name: GITHUB_RUNNER_JOB_NAME
        image: GITHUB_RUNNER_IMAGE_PATH
        resources: {
          cpu: '1.0'
          memory: '2.0Gi'
        }
        env: [
          { name: 'PEM', secretRef: 'pem' }
          { name: 'APP_ID', value: GITHUB_APP_ID }
          { name: 'ACCESS_TOKEN_API_URL', value: ACCESS_TOKEN_API_URL }
          { name: 'RUNNER_REGISTRATION_URL', value: GITHUB_RUNNER_REGISTRATION_URL }
          { name: 'REGISTRATION_TOKEN_API_URL', value: GITHUB_REGISTRATION_TOKEN_API_URL }
        ]
      }
    ]
    secrets: [
      {
        name: 'pem'
        //        keyVaultUrl: KEY_VAULT_PEMFILE_SECRET_URI // kv.outputs.uri when aca uses systemassigned-managedid -> The expression is involved in a cycle ("aca" -> "kv").
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
              owner: GITHUB_REPO_OWNER
              repos: GITHUB_REPO_NAME
              runnerScope: GITHUB_RUNNER_SCOPE
              targetWorkflowQueueLength: '1'
              applicationID: GITHUB_APP_ID
              installationID: GITHUB_APP_INSTALLATION_ID
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
output demo string = ContainerAppsEnvironment.id
