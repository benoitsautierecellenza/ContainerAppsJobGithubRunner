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
