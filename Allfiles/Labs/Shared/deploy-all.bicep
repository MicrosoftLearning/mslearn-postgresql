@description('Location for all resources.')
param location string = resourceGroup().location

@description('Unique name for the Azure Database for PostgreSQL.')
param serverName string = 'psql-learn-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('The version of PostgreSQL to use.')
param postgresVersion string = '16'

@description('Login name of the database administrator.')
@minLength(1)
param adminLogin string = 'pgAdmin'

@description('Password for the database administrator.')
@minLength(8)
@secure()
param adminLoginPassword string

@description('Unique name for the Azure OpenAI service.')
param azureOpenAIServiceName string = 'oai-learn-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Azure AI Language service account.')
param languageServiceName string = 'lang-learn-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Azure AI Translator service account.')
param translatorServiceName string = 'trn-learn-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Azure Machine Learning workspace.')
param workspaceName string = 'aml-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Log Analytics workspace.')
param logAnalyticsName string = 'la-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the storage account name.')
param storageAccountName string = 'sa${uniqueString(resourceGroup().id)}'

@description('Unique name for the Key Vault instance.')
param keyVaultName string = 'kv-${substring(resourceGroup().location, 0, 7)}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Application Insights instance.')
param appInsightsName string = 'appi-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the container registry.')
param containerRegistryName string = 'acr${resourceGroup().location}${uniqueString(resourceGroup().id)}'

@description('Restore the service instead of creating a new instance. This is useful if you previously soft-delted the service and want to restore it. If you are restoring a service, set this to true. Otherwise, leave this as false.')
param restore bool = false

@description('Creates a PostgreSQL Flexible Server.')
resource postgreSQLFlexibleServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: serverName
  location: location
  sku: {
    name: 'Standard_D2ds_v4'
    tier: 'GeneralPurpose'
  }
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminLoginPassword
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    createMode: 'Default'
    highAvailability: {
      mode: 'Disabled'
    }
    storage: {
      autoGrow: 'Disabled'
      storageSizeGB: 32
      tier: 'P10'
    }
    version: postgresVersion
  }
}

@description('Firewall rule that checks the "Allow public access from any Azure service within Azure to this server" box.')
resource allowAllAzureServicesAndResourcesWithinAzureIps 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  parent: postgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Firewall rule to allow all IP addresses to connect to the server. Should only be used for lab purposes.')
resource allowAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAll'
  parent: postgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

@description('Creates the "rentals" database in the PostgreSQL Flexible Server.')
resource rentalsDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: 'rentals'
  parent: postgreSQLFlexibleServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

@description('Configures the "azure.extensions" parameter to allowlist extensions.')
resource allowlistExtensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-03-01-preview' = {
  name: 'azure.extensions'
  parent: postgreSQLFlexibleServer
  dependsOn: [allowAllAzureServicesAndResourcesWithinAzureIps, allowAll, rentalsDatabase] // Ensure the database is created and configured before setting the parameter, as it requires a "restart."
  properties: {
    source: 'user-override'
    value: 'azure_ai,vector'
  }
}

@description('Creates an Azure OpenAI service.')
resource azureOpenAIService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: azureOpenAIServiceName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
    tier: 'Standard'
  }
  properties: {
    customSubDomainName: azureOpenAIServiceName
    publicNetworkAccess: 'Enabled'
    restore: restore
  } 
}

@description('Creates an embedding deployment for the Azure OpenAI service.')
resource azureOpenAIEmbeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: 'embedding'
  parent: azureOpenAIService
  sku: {
    name: 'Standard'
    capacity: 30
  }
  properties: {
    model: {
      name: 'text-embedding-ada-002'
      version: '2'
      format: 'OpenAI'
    }
  }
}

@description('Creates an Azure AI Language service account.')
resource languageService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: languageServiceName
  location: location
  kind: 'TextAnalytics'
  sku: {
    name: 'S'
  }
  properties: {
    customSubDomainName: languageServiceName
    publicNetworkAccess: 'Enabled'
    restore: restore
  } 
}

@description('Creates an Azure AI Translator service account.')
resource translatorService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: translatorServiceName
  location: location
  kind: 'TextTranslation'
  sku: {
    name: 'S1'
  }
  properties: {
    customSubDomainName: translatorServiceName
    publicNetworkAccess: 'Enabled'
    restore: restore
  } 
}

@description('Creates a storage account for Azure Machine Learning.')
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

@description('Creates a Key Vault for Azure Machine Learning.')
resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
  }
}

@description('Creates a log analytics workspace for use with Application Insights.')
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

@description('Creates an Application Inslights instance for Azure Machine Learning.')
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

@description('Creates a container registry for Azure Machine Learning.')
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
}

@description('Creates an Azure Machine Learning workspace.')
resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2021-07-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: workspaceName
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    applicationInsights: appInsights.id
    containerRegistry: containerRegistry.id
    description: 'Azure Machine Learning workspace for integration with PostgreSQL'
  }
}

output serverFqdn string = postgreSQLFlexibleServer.properties.fullyQualifiedDomainName
output serverName string = postgreSQLFlexibleServer.name
output databaseName string = rentalsDatabase.name

output azureOpenAIServiceName string = azureOpenAIService.name
output azureOpenAIEndpoint string = azureOpenAIService.properties.endpoint
output azureOpenAIEmbeddingDeploymentName string = azureOpenAIEmbeddingDeployment.name

output languageServiceName string = languageService.name
output languageServiceEndpoint string = languageService.properties.endpoint

output translatorServiceName string = translatorService.name
output translatorServiceEndpoint string = translatorService.properties.endpoint

output mlWorkspaceId string = mlWorkspace.id

output azureMLWorkspaceName string = mlWorkspace.name
