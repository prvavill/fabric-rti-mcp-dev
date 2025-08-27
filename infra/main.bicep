param name string
param location string = resourceGroup().location
param resourceToken string = toLower(uniqueString(subscription().id, name, location))

param tags object = {}
param pythonVersion string = '3.10'

var appServicePlanName = 'plan-${resourceToken}'
var functionAppName = 'func-${resourceToken}'
var applicationInsightsName = 'appi-${resourceToken}'
var storageAccountName = 'st${resourceToken}'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'Python|${pythonVersion}'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'PYTHONPATH'
          value: '/home/site/wwwroot/.python_packages/lib/site-packages'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FASTMCP_PATH'
          value: '/mcp'
        }
        {
          name: 'FASTMCP_HOST'
          value: '0.0.0.0'
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

output FUNCTION_APP_NAME string = functionApp.name
output FUNCTION_ENDPOINT string = 'https://${functionApp.properties.defaultHostName}'
