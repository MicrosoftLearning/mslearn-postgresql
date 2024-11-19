@description('Location for all resources.')
param location string = resourceGroup().location

@description('Unique name for the source Azure Database for PostgreSQL.')
param sourceServerName string = 'psql-learn-source-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

@description('Unique name for the Azure Database for PostgreSQL.')
param destinationServerName string = 'psql-learn-destination-${resourceGroup().location}-${uniqueString(resourceGroup().id)}'

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
param databaseName string = 'rentals'

@description('Creates the source PostgreSQL Flexible Server.')
resource sourcePostgreSQLFlexibleServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: sourceServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
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
resource sourceAllowAllAzureServicesAndResourcesWithinAzureIps 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'sourceAllowAllAzureServicesAndResourcesWithinAzureIps'
  parent: sourcePostgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Firewall rule to allow all IP addresses to connect to the server. Should only be used for lab purposes.')
resource sourceAllowAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'sourceAllowAll'
  parent: sourcePostgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

@description('Creates the "rentals" database in the PostgreSQL Flexible Server.')
resource Database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: databaseName
  parent: sourcePostgreSQLFlexibleServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

@description('Creates the destination PostgreSQL Flexible Server.')
resource destinationPostgreSQLFlexibleServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: destinationServerName
  location: location
  sku: {
    name: 'Standard_D2s_v3'
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
resource destinationAllowAllAzureServicesAndResourcesWithinAzureIps 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'destinatinAllowAllAzureServicesAndResourcesWithinAzureIps'
  parent: destinationPostgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Firewall rule to allow all IP addresses to connect to the server. Should only be used for lab purposes.')
resource destinationAllowAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'destinationAllowAll'
  parent: destinationPostgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

output sourceServerFqdn string = sourcePostgreSQLFlexibleServer.properties.fullyQualifiedDomainName
output sourceServerName string = sourcePostgreSQLFlexibleServer.name
output databaseName string = Database.name
output destServerFqdn string = destinationPostgreSQLFlexibleServer.properties.fullyQualifiedDomainName
output destServerName string = destinationPostgreSQLFlexibleServer.name

