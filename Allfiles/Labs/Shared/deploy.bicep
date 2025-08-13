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

@description('Name of the database.')
@minLength(1)
param databaseName string = 'rentals' // you override to ContosoHelpDesk at deploy time

@description('Unique name for the Azure OpenAI service.')
param azureOpenAIServiceName string = 'oai-learn-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Azure AI Language service account.')
param languageServiceName string = 'lang-learn-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Restore the service instead of creating a new instance. Set to true if soft-deleted resources exist.')
param restore bool = false

// ---------- OpenAI deployment parameters (parameterized names & versions) ----------

@description('Embedding model name')
param embeddingModelName string = 'text-embedding-ada-002'

@description('Embedding model version')
param embeddingModelVersion string = '2'

@description('Embedding deployment capacity (small for labs).')
param embeddingCapacity int = 1

@description('Chat model name (must be available in your region).')
param chatModelName string = 'gpt-4o-mini'

@description('Chat model version (date-stamped or "latest" depending on model).')
param chatModelVersion string = 'latest'

@description('Chat deployment capacity (small for labs).')
param chatCapacity int = 1

// ---------- PostgreSQL Flexible Server ----------

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

@description('Firewall rule to allow all IP addresses to connect to the server. Lab use only.')
resource allowAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAll'
  parent: postgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

@description('Creates the database in the PostgreSQL Flexible Server.')
resource rentalsDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: databaseName
  parent: postgreSQLFlexibleServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

@description('Allow-list extensions via the azure.extensions server parameter.')
resource allowlistExtensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-03-01-preview' = {
  name: 'azure.extensions'
  parent: postgreSQLFlexibleServer
  dependsOn: [
    allowAllAzureServicesAndResourcesWithinAzureIps
    allowAll
    rentalsDatabase
  ]
  properties: {
    source: 'user-override'
    value: 'azure_ai,vector'
  }
}

// ---------- Azure OpenAI ----------

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
  name: 'embedding' // matches OPENAI_EMBED_DEPLOYMENT in .env
  parent: azureOpenAIService
  sku: {
    name: 'Standard'
    capacity: embeddingCapacity
  }
  properties: {
    model: {
      name: embeddingModelName
      version: embeddingModelVersion
      format: 'OpenAI'
    }
  }
}

@description('Creates a chat deployment for the Azure OpenAI service.')
resource azureOpenAIChatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: 'chat' // matches OPENAI_CHAT_DEPLOYMENT in .env
  parent: azureOpenAIService
  sku: {
    name: 'Standard'
    capacity: chatCapacity
  }
  properties: {
    model: {
      name: chatModelName
      version: chatModelVersion
      format: 'OpenAI'
    }
  }
}

// ---------- Azure AI Language (shared by LP) ----------

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

// ---------- Outputs ----------

output serverFqdn string = postgreSQLFlexibleServer.properties.fullyQualifiedDomainName
output serverName string = postgreSQLFlexibleServer.name
output databaseName string = rentalsDatabase.name

output azureOpenAIServiceName string = azureOpenAIService.name
output azureOpenAIEndpoint string = azureOpenAIService.properties.endpoint
output azureOpenAIEmbeddingDeploymentName string = azureOpenAIEmbeddingDeployment.name
output azureOpenAIChatDeploymentName string = azureOpenAIChatDeployment.name

output languageServiceName string = languageService.name
output languageServiceEndpoint string = languageService.properties.endpoint
