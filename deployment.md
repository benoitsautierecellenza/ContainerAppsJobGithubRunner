# Deployment steps

## Technical prerequisites

Have the following Components installed : 

```PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Install-Module Microsoft.Graph -Scope CurrentUser -Repository PSGallery -Force
```

Prepare the required modules to be imported

```PowerShell
Import-Module Microsoft.Graph, Microsoft.Graph.Applications, Microsoft.Graph.Users
```

Have an Azure AD Entra Account with :

- Global Administrator role privilege granted
- Owner of an Azure subscription


## Create the Service principal

Authenticate to Azure

```PowerShell
Connect-AZAccount
```

Connect to the Graph API

```PowerShell
Connect-MgGraph -Scopes 'User.Read.All', 'Application.ReadWrite.All' -UseDeviceAuthentication -NoWelcome
```

Run the [Create_AzureADApplication.ps1](./Scripts/Create_AzureADApplication.ps1) script with the following parameters : 

- Environment : Prefix to be used for all resources
- githubOrgName : GitHub Organization Name
- SubscriptionID : valid Azure Subscription ID

```PowerShell
. .\Create_AzureADApplication.ps1 -Environment DEV -githubOrgName benoitsautierecellenza -SubscriptionID 5be15500-7328-4beb-871a-1498cd4b4536
```

## Populate GitHub Action secrets

Using outputs from the [Create_AzureADApplication.ps1](./Scripts/Create_AzureADApplication.ps1) script, populate required GitHub Action secrets related to the <Environment> :

- <Environment>_AZUREAD_TENANT_ID : Azure AD Entra Tenant unique Identiier
- <Environment>_SUBSCRIPTION_ID : Azure Subscription ID
- <Environment>_SPN_APPLICATION_CLIENT_ID : Service Principal Client ID provided by [Create_AzureADApplication.ps1](./Scripts/Create_AzureADApplication.ps1) script
- <Environment>_SPN_APPLICATION_SECRET : Service Principal Client secret provided by [Create_AzureADApplication.ps1](./Scripts/Create_AzureADApplication.ps1) script

For a `DEV` environment, variables would be named as documented below : 

- DEV_AZUREAD_TENANT_ID
- DEV_SUBSCRIPTION_ID
- DEV_SPN_APPLICATION_CLIENT_ID
- DEV_SPN_APPLICATION_SECRET

## Prepare the Github App 

A dedicated GitHub App will be created using the following procedure

1. Login into GitHub
2. Go to your picture profile
3. Select `Settings` in the account menu
4. Select `Developer Settings` 
5. Select `GitHub Apps`
6. Click on `New GitHub app`
7. Name GitHub App using the following naming convention : `<Environment>-BuildGitHubRunner-APP`
8. Provide a URL (can be a fake URL)
9.  Application description : GitHub App for GitHub Action Runner for environment `<Environment>`
10. `Enable Expire user authorization tokens`
11. Disable the WebHooks checkbox (not required in GitHub Runner context)
12. Set Variables to `Read only`
13. Set Secrets to `Read only`
14. Set Metadata to `Read only`
15. Select Content to `Read & Write`
16. Select `Only on this account`
17. Click to `Create GitHub App`
18. Keep `AppID` and `Client ID` informations
19. Click `Generate a private Key`
20. Save content of the download file 
21. Click on `Install App`
22. Click on `Install`
23. Select `Only select repositories` 
24. Select `the AzureFirewallAsaService` repository
25. Click `Install`
26. Once installed keep the URL of the GitHub installation ID URL

At the end of this procedure we have the following informations:

- GitHub Aplication ID of the GitHub Application
- GitHub Application Client ID
- GitHub Application Installation ID
- GitHub Application PEM Private Key file

Create required GitHub secrets :  
- <Environment>_GH_APP_ID : GitHub App Client ID
- <Environment>_GH_APP_INSTALLATION_ID : GitHub App Installation ID
- <Environment>_GH_APP_PEM : Content of the Private Key File

