#
# Create Azure AD Application required for GitHub Action deployment of Azure Firewall As a Service
#
# Version 1.0 - Initial Release - Benoît SAUTIERE
#
# Example :  . .\Create_AzureADApplication.ps1 -githubOrgName benoitsautierecellenza -ForceUpdate $true
#
#Requires -PSedition Core
#Requires -Version 7.0

Param(
    [Parameter(mandatory = $true)]
    [string]$githubOrgName,
    [Parameter(mandatory = $false)]
    [Bool]$ForceUpdate = $False
)
Set-StrictMode -Version 3.0
$VerbosePreference = 'SilentlyContinue' # Need to fix to Stop with module import 
[String]$githubRepoName = "AzureFirewallAsAService"
[String]$githubBranch = "main"
[String]$AzureADApplicationName = "AzureFirewallAsAService-GitHubAction-Workflow"
#
# Check Azure AD Authentication
# OK
$Check_AADAuthentication = $(az ad signed-in-user show)
If (([string]::IsNullOrEmpty($Check_AADAuthentication))) {
    #
    # Not connected to Azure AD
    # OK
    [String]$ErrorMessage = "Not connected to Azure AD, please execute az login --scope https://graph.microsoft.com//.default"
    Write-Error $ErrorMessage
}
else {
    #
    # Yes connected to Azure AD
    # OK
    $Convert = $Check_AADAuthentication | ConvertFrom-Json
    [String]$Message = "Currently connected with user $($Convert.userPrincipalName)."
    Write-Output $Message
}
#
# Check if Azure AD Application already exists or not
# Need to review how operation is performed
$CheckAADApplication = $(az ad sp list --display-name $AzureADApplicationName)
If ($CheckAADApplication -eq "[]") {
    #
    # Create the Azure AP Service principal with a secret
    # OK
    [String]$Message = "Azure AD Application named $AzureADApplicationName does not yet exists., create it."
    Write-Output $Message
    $appId = $(az ad sp create-for-rbac --name $AzureADApplicationName --skip-assignment true --sdk-auth) # Include create secret
    $Convert = $appId | Convertfrom-Json
    Write-Output "clientId $($Convert.clientId)"
    Write-Output "clientSecret $($Convert.clientSecret)"
    Write-Output "tenantId $($Convert.tenantId)"
    [String]$Message = "Create a federated credential for $githubOrgName/$githubRepoName"
    Write-Output $Message
    #
    # Create the Federated credential
    # OK
    $githubBranchConfig = [PSCustomObject]@{
        name        = "GH-[$githubOrgName-$githubRepoName]-Branch-[$githubBranch]"
        issuer      = "https://token.actions.githubusercontent.com"
        subject     = "repo:" + "$githubOrgName/$githubRepoName" + ":ref:refs/heads/$githubBranch"
        description = "Federated credential linked to GitHub [$githubBranch] branch @: [$githubOrgName/$githubRepoName]"
        audiences   = @("api://AzureADTokenExchange")
    }
    $githubBranchConfigJson = $githubBranchConfig | ConvertTo-Json
    $githubBranchConfigJson | az ad app federated-credential create --id $Convert.clientId --parameters "@-"
    [String]$Message = "Federated credential succesfully created."
    Write-Output $Message
}
else {
    #
    # Azure AD Application required for Azure Firewall As a Service Already exists
    # OK
    [String]$Message = "Azure AD Application named $AzureADApplicationName already exists. retreive it."
    Write-Output $Message
    $appId = $(az ad sp list --display-name $AzureADApplicationName)
    $AAdApplicationConfiguration = $appId | Convertfrom-Json
    If ($ForceUpdate -eq $true) {
        [String]$Message = "Perform credential refresh"
        Write-Output $Message
        $CheckForFederatedCredentials = $(az ad app federated-credential list --id $AAdApplicationConfiguration.appId)
        If ($CheckForFederatedCredentials -eq "[]") {
            #
            # Create the Federated Credentials
            # OK
            [String]$Message = "Create a federated credential for $githubOrgName/$githubRepoName"
            Write-Output $Message
            $githubBranchConfig = [PSCustomObject]@{
                name        = "GH-[$githubOrgName-$githubRepoName]-Branch-[$githubBranch]"
                issuer      = "https://token.actions.githubusercontent.com"
                subject     = "repo:" + "$githubOrgName/$githubRepoName" + ":ref:refs/heads/$githubBranch"
                description = "Federated credential linked to GitHub [$githubBranch] branch @: [$githubOrgName/$githubRepoName]"
                audiences   = @("api://AzureADTokenExchange")
            }
            $githubBranchConfigJson = $githubBranchConfig | ConvertTo-Json
            $githubBranchConfigJson | az ad app federated-credential create --id $AAdApplicationConfiguration.appId --parameters "@-"
            [String]$Message = "Federated credential succesfully created."
            Write-Output $Message
        }
        else {
            #
            # Perform first a delete of the existing Federated credential
            # OK
            $Convert = $CheckForFederatedCredentials | Convertfrom-Json
            [String]$Message = "Delete existing Federated credential $($convert.name)."
            Write-Output $Message
            az ad app federated-credential delete --id $AAdApplicationConfiguration.appId --federated-credential-id $Convert.id
            [String]$Message = "Federated credential $($convert.name) deleted ."
            Write-Output $Message

            [String]$Message = "Create a new federated credential for $githubOrgName/$githubRepoName"
            Write-Output $Message
            $githubBranchConfig = [PSCustomObject]@{
                name        = "GH-[$githubOrgName-$githubRepoName]-Branch-[$githubBranch]"
                issuer      = "https://token.actions.githubusercontent.com"
                subject     = "repo:" + "$githubOrgName/$githubRepoName" + ":ref:refs/heads/$githubBranch"
                description = "Federated credential linked to GitHub [$githubBranch] branch @: [$githubOrgName/$githubRepoName]"
                audiences   = @("api://AzureADTokenExchange")
            }
            $githubBranchConfigJson = $githubBranchConfig | ConvertTo-Json
            $githubBranchConfigJson | az ad app federated-credential create --id $AAdApplicationConfiguration.appId --parameters "@-"
            [String]$Message = "Federated a new credential succesfully created."
            Write-Output $Message
        }
        #
        # perform a reset of existing Client-Secret 
        #
        [String]$Message = "Performing reset of exisring client se ret linked to $($AAdApplicationConfiguration.displayName)"
        Write-Output $Message
        az ad app credential reset --id $AAdApplicationConfiguration.appId --years 1
    }
    else {
        [String]$Message = "No credentials refresh performed"
        Write-Output $Message
    }
}