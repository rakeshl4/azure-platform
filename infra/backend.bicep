targetScope = 'resourceGroup'

@description('Required. Azure location to which the resources are to be deployed')
param location string

@description('Required. The naming module for facilitating naming convention.')
param naming object

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

param appInsightsName string
param storageAccountName string
param appServicePlanName string

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' existing = {
  name: appServicePlanName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

var placeholder = '***'
var funcNameWithPlaceholder = replace(naming.functionApp.name, '${naming.functionApp.slug}-', '${naming.functionApp.slug}-${placeholder}-')
var todoFunctionAppName = replace(funcNameWithPlaceholder, placeholder, 'todo')

resource provisionTeamsFunctionApp 'Microsoft.Web/sites@2021-02-01' = {
  name: todoFunctionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
    // userAssignedIdentities: {
    //   '${managedIdentity.id}': {}
    // }
  }
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    // keyVaultReferenceIdentity: managedIdentity.id
    // httpsOnly: true
    // virtualNetworkSubnetId: appServiceSubnet.id
    siteConfig: {
      powerShellVersion: '7.2'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        // {
        //   name: 'ServiceBusConnection__fullyQualifiedNamespace'
        //   value: '${serviceBusNamespace.name}.servicebus.windows.net'
        // }
        {
          name: 'ServiceBusConnection__credential'
          value: 'managedIdentity'
        }
        // {
        //   name: 'ServiceBusConnection__clientId'
        //   value: managedIdentity.properties.clientId
        // }
        // {
        //   name: 'AzureAdClientId'
        //   value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${functionAADServicePrincipalClientIdSecretName})'
        // }
        // {
        //   name: 'AzureAdClientSecret'
        //   value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${functionAADServicePrincipalClientSecretSecretName})'
        // }
        {
          name: 'AzureAdTenantId'
          value: subscription().tenantId
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(todoFunctionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}
