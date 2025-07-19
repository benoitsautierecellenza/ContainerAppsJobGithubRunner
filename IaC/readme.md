New-AzSubscriptionDeployment -Location francecentral -TemplateFile solution.bicep

az acr list --query [].name --output tsv
az acr login --name acrnprdab2cae523be



az acr build --registry acrnprdab2cae523be --image acrnprdab2cae523be.azurecr.io/runner_base:2.325.0 . --build-arg 'RUNNER_VERSION=2.325.0' --build-arg 'DOTNET_VERSION=9.0' --build-arg 'PS_VERSION=7.4.5' --build-arg 'AZACCOUNTS_VERSION=3.0.4' --build-arg 'AZKEYVAULT_VERSION=6.2.0' --build-arg 'AZSTORAGE_VERSION=7.4.0' --build-arg 'AZAPPINSIGHT_VERSION=2.2.5' --build-arg 'AZNETWORK_VERSION=7.10.0' --build-arg 'AZRESOURCES_VERSION=7.5.0' --build-arg 'AZ_TABLE_VERSION=2.1.0' --build-arg 'MS_GRAPH_VERSION=2.24.0' --build-arg 'MS_ENTRA_VERSION=1.0.1' --build-arg 'TERRAFORM_VERSION=1.10.0' --build-arg 'TERRAGRUNT_VERSION=0.72.2' --build-arg 'AZURECLI_VERSION=2.74.0' --build-arg  'UBUNTU_LTS_VERSION=jammy'


New-AzResourceGroupDeployment -ResourceGroupName RG-nprd-acarunner-1.0 -TemplateFile acajob.bicep
