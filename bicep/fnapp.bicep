targetScope= 'resourceGroup'

param environment string = 'dev'  /// Use prod for production
param location string = resourceGroup().location
param storageAccountSku string = 'Standard_LRS'

var name = 'hello-world'
var logicAppName = 'logicapp-${name}-${environment}'
var minimumElasticSize = 1
var maximumElasticSize = 3
var unique = uniqueString(resourceGroup().id)

resource logicAppStorage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: 'stor${unique}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageAccountSku
  }
  properties: {
    allowBlobPublicAccess: false
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

 /// Dedicated app plan for the service ///
 resource servicePlanLogicApp 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: 'plan-${name}-logic-app-${environment}'
  location: location
  sku: {
    tier: 'WorkflowStandard'
    name: 'WS1'
  }
  properties: {
    targetWorkerCount: minimumElasticSize
    maximumElasticWorkerCount: maximumElasticSize
    elasticScaleEnabled: true
    isSpot: false
    zoneRedundant: ((environment == 'prod') ? true : false)
  }
}

// App service containing the workflow runtime ///
resource siteLogicApp 'Microsoft.Web/sites@2021-02-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorage.name};AccountKey=${listKeys(logicAppStorage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorage.name};AccountKey=${listKeys(logicAppStorage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'app-${toLower(name)}-logicservice-${toLower(environment)}a6e9'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: resourceGroup().name
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      use32BitWorkerProcess: true
    }
    serverFarmId: servicePlanLogicApp.id
    clientAffinityEnabled: false
  }
}


