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

- `Environment` : Prefix to be used for all resources
- `githubOrgName` : GitHub Organization Name
- `SubscriptionID` : valid Azure Subscription ID

```PowerShell
. .\Create_AzureADApplication.ps1 -Environment DEV -githubOrgName benoitsautierecellenza -SubscriptionID 5be15500-7328-4beb-871a-1498cd4b4536
```

## Populate GitHub Action secrets

Using outputs from the [Create_AzureADApplication.ps1](./Scripts/Create_AzureADApplication.ps1) script, populate required GitHub Action secrets related to the <Environment> :

- `<Environment>_AZUREAD_TENANT_ID` : Azure AD Entra Tenant unique Identiier
- `<Environment>_SUBSCRIPTION_ID` : Azure Subscription ID
- `<Environment>_SPN_APPLICATION_CLIENT_ID` : Service Principal Client ID provided by [Create_AzureADApplication.ps1](./Scripts/Create_AzureADApplication.ps1) script
- `<Environment>_SPN_APPLICATION_SECRET` : Service Principal Client secret provided by [Create_AzureADApplication.ps1](./Scripts/Create_AzureADApplication.ps1) script

For a `DEV` environment, GitHub secrets would be named as documented below : 

- DEV_AZUREAD_TENANT_ID
- DEV_SUBSCRIPTION_ID
- DEV_SPN_APPLICATION_CLIENT_ID
- DEV_SPN_APPLICATION_SECRET

## Prepare the Github App for GitHub Workflow

A dedicated GitHub App will be created using the following procedure:

1. Login into GitHub
2. Go to your picture profile
3. Select `Settings` in the account menu
4. Select `Developer Settings` 
5. Select `GitHub Apps`
6. Click on `New GitHub app`
7. Name GitHub App using the following naming convention : `<Environment>-BuildGitHubRunner-APP`
8. Provide a URL (can be a fake URL)
9.  Application description : GitHub App for GitHub Runner image build workflow for environment `<Environment>`
10. Check `Enable Expire user authorization tokens`
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
- `<Environment>_GH_APP_ID` : GitHub App Client ID
- `<Environment>_GH_APP_INSTALLATION_ID` : GitHub App Installation ID
- `<Environment>_GH_APP_PEM` : Content of the Private Key File

For a `DEV` environment, GitHub secrets would be named as documented below : 

- `DEV_GH_APP_ID` : GitHub App Client ID
- `DEV_GH_APP_INSTALLATION_ID` : GitHub App Installation ID
- `DEV_GH_APP_PEM` : Content of the Private Key File

## Prepare the Github App for GitHub Runner

A dedicated GitHub App will be created using the following procedure

1. Login into GitHub
2. Go to your picture profile
3. Select `Settings` in the account menu
4. Select `Developer Settings` 
5. Select `GitHub Apps`
6. Click on `New GitHub app`
7. Name GitHub App using the following naming convention : `<Environment>-GHRunner-APP`
8. Provide a URL (can be a fake URL)
9.  Application description : GitHub App for GitHub Action Runner for environment `<Environment>`
10. Check `Enable Expire user authorization tokens`
11. Disable the WebHooks checkbox (not required in GitHub Runner context)
12. Set Action to `Read only`
12. Set Administration to `Read only`
12. Set Variables to `Read & write` (Check if required)
14. Set Metadata to `Read only`
15. Select `Only on this account`
16. Click to `Create GitHub App`
17. Keep `AppID` and `Client ID` informations
18. Click `Generate a private Key`
19. Save content of the download file 
20. Click on `Install App`
21. Click on `Install`
22. Select `Only select repositories` 
23. Select `the AzureFirewallAsaService` repository
24. Click `Install`
25. Once installed keep the URL of the GitHub installation ID URL

At the end of this procedure we have the following informations:

- GitHub Aplication ID of the GitHub Application
- GitHub Application Client ID
- GitHub Application Installation ID
- GitHub Application PEM Private Key file

Create required GitHub secrets :  
- `<Environment>_GHRUNNER_APP_ID` : GitHub App Client ID
- `<Environment>_GHRUNNER_APP_INSTALLATION_ID` : GitHub App Installation ID
- `<Environment>_GHRUNNER_APP_PEM` : Content of the Private Key File

For a `DEV` environment, GitHub secrets would be named as documented below : 

- `DEV_GHRUNNER_APP_ID` : GitHub App Client ID
- `DEV_GHRUNNER_APP_INSTALLATION_ID` : GitHub App Installation ID
- `DEV_GHRUNNER_APP_PEM` : Content of the Private Key File

Issue Move DEV_GHRUNNER_APP_PEM to KeyVault Secret or add as task to setup the secret