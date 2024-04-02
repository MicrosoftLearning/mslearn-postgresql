@description('Location for all resources.')
param location string = resourceGroup().location

@description('Unique name for the Azure Database for PostgreSQL Flexible Server.')
param serverName string = 'pgsql-learn-${uniqueString(resourceGroup().id)}'

@description('Login name of the database administrator.')
@minLength(1)
param administratorLogin string = 'pgAdmin'

@description('Password for the database administrator.')
@minLength(8)
@secure()
param administratorLoginPassword string = 'Password123!'

@description('The version of PostgreSQL to use.')
param version string = '16'

@description('Unique name for the Azure OpenAI service.')
param azureOpenAIServiceName string = 'azopenai-pgsql-learn-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Azure AI Language service account.')
param languageServiceName string = 'lang-pgsql-learn-${uniqueString(resourceGroup().id)}'

@description('Creates a PostgreSQL Flexible Server.')
resource postgreSQLFlexibleServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: serverName
  location: location
  sku: {
    name: 'Standard_D2ds_v5'
    tier: 'GeneralPurpose'
  }
  properties: {
    createMode: 'Default'
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    storage: {
      storageSizeGB: 32
      tier: 'P4'
    }
  }
}

@description('Creates the "rentals" database in the PostgreSQL Flexible Server.')
resource rentalsDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: 'rentals'
  parent: postgreSQLFlexibleServer
}

@description('Firewall rule that checks the "Allow all Azure services to access the server" box.')
resource allowAllWindowsAzureIps 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAllWindowsAzureIps' // don't change the name
  parent: postgreSQLFlexibleServer
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

@description('Firewall rule to allow all IP addresses to connect to the server.')
resource allowAllIpAddresses 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAllIps'
  parent: postgreSQLFlexibleServer
  properties: {
    endIpAddress: '255.255.255.255'
    startIpAddress: '0.0.0.0'
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
    publicNetworkAccess: 'Enabled'
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
    publicNetworkAccess: 'Enabled'
  } 
}

output serverFqdn string = postgreSQLFlexibleServer.properties.fullyQualifiedDomainName
output serverName string = postgreSQLFlexibleServer.name
output databaseName string = rentalsDatabase.name

output azureOpenAIServiceName string = azureOpenAIService.name
output azureOpenAIEndpoint string = azureOpenAIService.properties.endpoint

output languageServiceName string = languageService.name
output languageServiceEndpoint string = languageService.properties.endpoint
