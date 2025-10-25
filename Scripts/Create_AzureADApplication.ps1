#
# Create Azure AD Application required for GitHub Action deployment of Azure Firewall As a Service
#
# Version 1.2 - Fixed authentication issues with Microsoft Graph module
# Version 1.1 - Updated release to no longer rely on Azure CLI & detect missing authentication with Azure AD Entra + Azure subscription selection
# Version 1.0 - Initial Release - Benoît SAUTIERE
#
# Example :  . .\Create_AzureADApplication.ps1 -Environment PRD -githubOrgName benoitsautierecellenza -SubscriptionID 5be15500-7328-4beb-871a-1498cd4b4536
#
#Requires -PSedition Core
#Requires -Version 7.0
#Requires -Modules  Microsoft.Graph, Microsoft.Graph.Applications, Microsoft.Graph.Users

Param(
    [Parameter(mandatory = $true)]
    [string]$Environment,
    [Parameter(mandatory = $true)]
    [string]$githubOrgName,
    [Parameter(mandatory = $true)]
    [string]$SubScriptionId
)
#Set-StrictMode -Version 3.0
$VerbosePreference = 'SilentlyContinue' # Need to fix to Stop with module import 
[String]$githubRepoName = "ContainerAppsJobGithubRunner"
[String]$githubBranch = "main"
[String]$AzureADApplicationName = "ContainerAppsJobGithubRunner-$Environment-GitHubAction-Workflow"
#
# Check Azure AD Authentication
# OK
# Get-MGContext est vide ?
$CheckGraphContext = Get-MGContext
If (([string]::IsNullOrEmpty($CheckGraphContext))) {
    #
    # Not connected to Microsoft Graph
    # OK
    # Implique le consentement de l'organisation pour les permissions
    # Connect-MgGraph -Scopes 'User.Read.All', 'Application.ReadWrite.All' -UseDeviceAuthentication -NoWelcome
    [String]$ErrorMessage = "Not connected to Microsoft Graph, please execute Connect-MgGraph -Scopes 'User.Read.All', 'Application.ReadWrite.All'"
    Write-Error $ErrorMessage
    exit
}
else {
    #
    # Yes connected to Microsoft Graph
    # OK
    [String]$Message = "Currently connected to Microsoft Graph with user $($CheckGraphContext.Account)."
    $CurrentGraphContext = Get-MgUser -Filter "UserPrincipalName eq '$($CheckGraphContext.Account)'"
    Write-Output $Message
}
# Get current Azure Subscription to be used for the Azure AD Application role assignment
$CurrentAzureSubscription = Get-AzContext -ErrorAction SilentlyContinue
If (([string]::IsNullOrEmpty($CurrentAzureSubscription))) {
    #
    # Not connected to Azure Subscription
    # OK
    [String]$ErrorMessage = "Not connected to Azure Subscription, please execute Connect-AzAccount first."
    Write-Error $ErrorMessage
}
else {
    #
    # Yes connected to Azure Subscription
    # OK
    [String]$Message = "User is connected to Azure."
    Write-Output $Message
}
#
# check if provided subscription ID is valid
# OK
$Subscription_list = Get-AzSubscription
If (($Subscription_list.id) -contains $SubScriptionId) {
    #
    # Provided subscription ID is valid
    # OK
    [String]$Message = "Provided subscription ID '$SubScriptionId' is valid."
    Write-Output $Message
    $Scope = "/subscriptions/$SubScriptionId"
}
else {
    [String]$Message = "Provided subscription ID '$SubScriptionId' is not valid or you do not have access to it."
    Write-Error $Message
    exit
} 
# Check if Azure AD Application already exists or not
# OK
$CheckAADApplication = Get-MgApplication -filter "DisplayName eq '$AzureADApplicationName'"
If (([string]::IsNullOrEmpty($CheckAADApplication))) {
    #
    # Create the Azure AP Service principal with a secret
    # OK
    [String]$Message = "Azure AD Application named $AzureADApplicationName does not yet exists, create it."
    Write-Output $Message
    $NewAppRegistration = New-MgApplication -DisplayName $AzureADApplicationName 
    $NewOwner = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/{$($CurrentGraphContext.id)}"
    }
    New-MgApplicationOwnerByRef -ApplicationId $NewAppRegistration.Id -BodyParameter $NewOwner  
    $passwordCred = @{
        displayName = 'Created using Create_AzureADApplication.ps1'
        endDateTime = (Get-Date).AddMonths(6)
    }
    $secret = Add-MgApplicationPassword -applicationId $NewAppRegistration.Id -PasswordCredential $passwordCred
    $githubBranchConfig = @{
        name        = "GH-[$githubOrgName-$githubRepoName]-Branch-[$githubBranch]"
        issuer      = "https://token.actions.githubusercontent.com"
        subject     = "repo:" + "$githubOrgName/$githubRepoName" + ":ref:refs/heads/$githubBranch"
        description = "Federated credential linked to GitHub [$githubBranch] branch @: [$githubOrgName/$githubRepoName]"
        audiences   = @("api://AzureADTokenExchange")
    }
    New-MgApplicationFederatedIdentityCredential -ApplicationId $NewAppRegistration.Id -BodyParameter $githubBranchConfig # Create the Federated Credential
    $NewServicePrincipal = New-MgServicePrincipal -AppId ($NewAppRegistration.AppId) # Create the related service principal
    Start-Sleep -Seconds 60 # Wait for the service principal to be created in Azure AD
    $NewRoleAssignment = New-AzRoleAssignment -Scope $Scope -RoleDefinitionName "owner" -ObjectId $NewServicePrincipal.Id -Description "Role assignment for $($NewServicePrincipal.DisplayName)" -ErrorAction Stop # Create the role assignment for the service principal
    Write-Output "Azure AD Application $($NewAppRegistration.DisplayName) created successfully."
    Write-Output "Client ID $($NewAppRegistration.AppId)"
    Write-Output "Linked Service Principal $($NewServicePrincipal.DisplayName) created successfully."
    Write-Output "Secret for Azure AD Application $($NewAppRegistration.DisplayName) created successfully : $($secret.SecretText)"
}
else {
    #
    # Azure AD Application required for Azure Firewall As a Service Already exists
    # OK
    [String]$Message = "Azure AD Application named $AzureADApplicationName already exists."
    Write-Output $Message
    #
    # Check if connected user is also woner of the Azure AD Entra Application
    # OK
    $CheckOwner = Get-MgApplicationByAppId -AppId $CheckAADApplication.AppId -ExpandProperty Owners
    If (([string]::IsNullOrEmpty($CheckOwner.owners))) {
        #
        # Current user is not owner of Azure AD Application
        # OK
        [string]$Message = "Current user $($CurrentGraphContext.userPrincipalName) is not owner of Azure AD Application $AzureADApplicationName, adding it."
        Write-Output $Message
        $NewOwner = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/{$($CurrentGraphContext.id)}"
        }
        New-MgApplicationOwnerByRef -ApplicationId $CheckAADApplication.Id -BodyParameter $NewOwner
        [String]$Message = "User $($CurrentGraphContext.userPrincipalName) added as owner of Azure AD Application $AzureADApplicationName."
        Write-Output $Message
    }
    else {
        If ( ($CheckOwner.Owners.id) -contains $CurrentGraphContext.id ) {
            #
            # Current user is already owner of Azure AD Application
            # OK
            [string]$Message = "Current user $($CurrentGraphContext.userPrincipalName) is already owner of Azure AD Application $AzureADApplicationName."
            Write-Output $Message
        }
        else {
            #
            # Current user is not owner of Azure AD Application
            # OK
            [string]$Message = "Current user $($CurrentGraphContext.userPrincipalName) is not owner of Azure AD Application $AzureADApplicationName, adding it."
            Write-Output $Message
            $NewOwner = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/{$($CurrentGraphContext.id)}"
            }
            New-MgApplicationOwnerByRef -ApplicationId $CheckAADApplication.Id -BodyParameter $NewOwner
            [String]$Message = "User $($CurrentGraphContext.userPrincipalName) added as owner of Azure AD Application $AzureADApplicationName."
            Write-Output $Message
        }
    }
    #
    # Check if Password credential exists, is not expired, if expired then update and provide secret
    # 
    $AzureADApplication = Get-MgApplicationByAppId -AppId $CheckAADApplication.AppId
    if (($AzureADApplication.PasswordCredentials | Measure-Object).count -Gt 0) {
        #
        # Password credential exists, check if it is expired
        # OK
        $PasswordCredential = $AzureADApplication.PasswordCredentials | Where-Object { $_.EndDateTime -gt (Get-Date) }
        if ($PasswordCredential) {
            #
            # Password credential is not expired
            # OK
            [String]$Message = "Password credential for Azure AD Application $AzureADApplicationName is not expired."
            Write-Output $Message
        }
        else {
            #
            # Password credential is expired, update it and provide secret
            # OK
            [String]$Message = "Password credential for Azure AD Application $AzureADApplicationName is expired, updating it."
            Write-Output $Message
            $passwordCred = @{
                displayName = 'Created using Create_AzureADApplication.ps1'
                endDateTime = (Get-Date).AddMonths(6)
            }
            $secret = Add-MgApplicationPassword -applicationId $CheckAADApplication.Id -PasswordCredential $passwordCred
            [String]$Message = "Secret for Azure AD Application $AzureADApplicationName updated successfully : $($secret.SecretText)"
            Write-Output $Message
        }
    }
    else {
        #
        # No password credential exists, create it and provide secret
        # OK
        [String]$Message = "No password credential for Azure AD Application $AzureADApplicationName, creating it."
        Write-Output $Message
        $passwordCred = @{
            displayName = 'Created using Create_AzureADApplication.ps1'
            endDateTime = (Get-Date).AddMonths(6)
        }
        $secret = Add-MgApplicationPassword -applicationId $CheckAADApplication.Id -PasswordCredential $passwordCred
        [String]$Message = "Secret for Azure AD Application $AzureADApplicationName created successfully : $($secret.SecretText)"
        Write-Output $Message
    }
}