@description('Location for all resources.')
param location string = resourceGroup().location

@description('Unique name for the Azure Database for PostgreSQL.')
param serverName string = 'psql-learn-${location}-${uniqueString(resourceGroup().id)}'

@description('PostgreSQL major version.')
param postgresVersion string = '16'

@description('Login name of the database administrator.')
@minLength(1)
param adminLogin string = 'pgAdmin'

@description('Password for the database administrator.')
@minLength(8)
@secure()
param adminLoginPassword string

@description('Name of the database.')
@minLength(1)
param databaseName string = 'rentals'

@description('Unique name for the Azure OpenAI service.')
param azureOpenAIServiceName string = 'oai-learn-${location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Azure AI Language service account.')
param languageServiceName string = 'lang-learn-${location}-${uniqueString(resourceGroup().id)}'

@description('Restore soft-deleted resources instead of creating new ones.')
param restore bool = false

// -------------------------
// PostgreSQL Flexible Server
// -------------------------
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

@description('Allow public access from any Azure service within Azure to this server.')
resource allowAllAzureServicesAndResourcesWithinAzureIps 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  parent: postgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Allow all IP addresses (lab use only).')
resource allowAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAll'
  parent: postgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

@description('Create the database.')
resource db 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: databaseName
  parent: postgreSQLFlexibleServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

// Allow-list extensions at the server level
resource allowlistExtensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-03-01-preview' = {
  name: 'azure.extensions'
  parent: postgreSQLFlexibleServer
  dependsOn: [
    allowAllAzureServicesAndResourcesWithinAzureIps
    allowAll
    db
  ]
  properties: {
    source: 'user-override'
    value: 'azure_ai,vector'
  }
}

// -------------------------
// Cognitive Services: OpenAI
// -------------------------
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

// -------------------------
// Cognitive Services: Language
// -------------------------
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

// -------------------------
// Outputs
// -------------------------
output serverFqdn string = postgreSQLFlexibleServer.properties.fullyQualifiedDomainName
output serverName string = postgreSQLFlexibleServer.name
output databaseName string = db.name

output azureOpenAIServiceName string = azureOpenAIService.name
output azureOpenAIEndpoint string = azureOpenAIService.properties.endpoint

output languageServiceName string = languageService.name
output languageServiceEndpoint string = languageService.properties.endpoint
