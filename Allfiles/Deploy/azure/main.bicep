// Complete Oracle -> Azure Database for PostgreSQL rapid migration POC in one
// deployment. Everything runs inside a single virtual network, reached privately
// over Azure Bastion:
//   * Windows workstation: desktop VS Code + the Microsoft PostgreSQL extension
//     (Migration Wizard) + Oracle Instant Client + Azure CLI.
//   * Oracle source: Ubuntu VM running Oracle Database Free 23ai in a container,
//     seeded with a sample HR schema (service FREEPDB1, port 1521).
//   * PostgreSQL target: Azure Database for PostgreSQL flexible server (private
//     access, no public endpoint).
//   * AI conversion: Azure OpenAI (Microsoft Foundry) account + model deployment;
//     the workstation's managed identity is granted key-less access.
//
// Access model: RDP only, via an Azure Bastion tunnel. No public RDP port, no
// public web ports; the databases are reachable only from within the VNet. The
// admin password is set at deploy time (adminPassword) and reused for the Oracle
// and PostgreSQL admin accounts. Connect after deployment:
//   az network bastion tunnel -n oracle-bridge-bastion -g <rg> \
//     --target-resource-id <vm-id> --resource-port 3389 --port 13389
//   # then RDP to localhost:13389
//
//   az group create -n oracle-bridge-rg -l westeurope
//   az deployment group create -g oracle-bridge-rg -f main.bicep \
//     -p adminUsername=azureuser adminPassword='<strong-password>'

@description('Admin username for the workstation VM (RDP login) and the Oracle and PostgreSQL admin accounts.')
param adminUsername string

@description('Password for the RDP login and for the Oracle and PostgreSQL admin accounts. Must satisfy Windows, Oracle, and PostgreSQL complexity rules.')
@secure()
param adminPassword string

@description('Azure region. Defaults to the resource group region.')
param location string = resourceGroup().location

@description('Workstation VM size. D4s_v3 = 4 vCPU / 16 GB and is broadly available. If you prefer a newer family and have quota, use a Dsv5/Dasv5 size (for example Standard_D4s_v5).')
param vmSize string = 'Standard_D4s_v3'

@description('Oracle source VM size (Linux; runs Oracle Database Free 23ai in a container).')
param oracleVmSize string = 'Standard_D2s_v3'

@description('PostgreSQL flexible server compute tier. The compute SKU size is derived from this tier.')
@allowed([ 'Burstable', 'GeneralPurpose', 'MemoryOptimized' ])
param postgresSkuTier string = 'Burstable'

@description('PostgreSQL major version.')
param postgresVersion string = '16'

@description('Name of the dedicated PostgreSQL database used as the migration scratch/sandbox target. Keeps converted objects out of the default \'postgres\' maintenance database.')
param scratchDatabaseName string = 'migration_sandbox'

@description('Name of the Azure OpenAI (Microsoft Foundry) model deployment used for the conversion.')
param openAiDeploymentName string = 'gpt-5-mini'

@description('Azure OpenAI model name.')
param openAiModelName string = 'gpt-5-mini'

@description('Azure OpenAI model version.')
param openAiModelVersion string = '2025-08-07'

@description('Azure OpenAI deployment SKU. GlobalStandard is broadly available for gpt-5-mini.')
param openAiSkuName string = 'GlobalStandard'

@description('Azure OpenAI deployment capacity, in thousands of tokens per minute (TPM).')
param openAiCapacity int = 10

@description('DNS label prefix for the workstation public IP. Must be globally unique in the region.')
param dnsLabelPrefix string = 'oracle-bridge-${uniqueString(resourceGroup().id)}'

@description('Deploy the Windows migration workstation and Azure Bastion access.')
param deployWorkstation bool = true

@description('Deploy the Oracle source VM and sample HR schema.')
param deployOracle bool = true

@description('Deploy the Azure Database for PostgreSQL flexible server target.')
param deployPostgres bool = true

@description('Deploy the Azure OpenAI account and model used for AI-assisted conversion.')
param deployOpenAi bool = true

var suffix       = uniqueString(resourceGroup().id)
var vnetName     = 'oracle-bridge-vnet'
var subnetName   = 'default'
var oracleSubnet = 'oracle'
var pgSubnet     = 'postgres'
var nsgName      = 'oracle-bridge-nsg'
var pipName      = 'oracle-bridge-pip'
var nicName      = 'oracle-bridge-nic'
var vmName       = 'migration-workstation'
var bastionName  = 'oracle-bridge-bastion'
var oracleVmName = 'oracle-source-vm'
var oracleNicName = 'oracle-source-nic'
var pgName       = 'orabridge-pg-${suffix}'
var openaiName   = 'orabridge-oai-${suffix}'
var pgDnsZoneName = '${pgName}.private.postgres.database.azure.com'
var deployNetwork = deployWorkstation || deployOracle || deployPostgres

// PostgreSQL compute SKU size, derived from the selected tier so the two always match.
var pgSkuNameMap = {
  Burstable: 'Standard_B2s'
  GeneralPurpose: 'Standard_D2ds_v5'
  MemoryOptimized: 'Standard_E2ds_v5'
}
var pgSkuName = pgSkuNameMap[postgresSkuTier]

// Windows computer names must be <= 15 characters.
var computerName = 'migration-ws'
var postgresHost = deployPostgres ? postgres.properties.fullyQualifiedDomainName : ''
var oracleHost = deployOracle ? oracleNic.properties.ipConfigurations[0].properties.privateIPAddress : ''
var foundryEndpoint = deployOpenAi ? openai.properties.endpoint : ''

// Cloud-init for the Oracle source VM, with deploy-time values substituted in.
// The Oracle VM also installs the recommended PostgreSQL extensions into the
// scratch database (it shares the admin password and can reach PG privately),
// so the __PG_* tokens carry the target connection details.
var oracleCloudInit = replace(replace(replace(replace(replace(loadTextContent('cloud-init.yaml'),
  '__ADMIN_USERNAME__', adminUsername),
  '__ORACLE_PWD__',     adminPassword),
  '__PG_FQDN__',        postgresHost),
  '__PG_ADMIN__',       adminUsername),
  '__PG_DATABASE__',    scratchDatabaseName)

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = if (deployNetwork) {
  name: nsgName
  location: location
  properties: {
    // No public inbound web ports. The desktop is reached only over Azure
    // Bastion: RDP (3389) is allowed solely from within the virtual network.
    securityRules: [
      {
        name: 'AllowRdpFromBastion'
        properties: {
          priority: 1000, protocol: 'Tcp', access: 'Allow', direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*'
          destinationAddressPrefix: '*', destinationPortRange: '3389'
        }
      }
      {
        name: 'AllowOracleFromVnet'
        properties: {
          priority: 1010, protocol: 'Tcp', access: 'Allow', direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*'
          destinationAddressPrefix: '*', destinationPortRange: '1521'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = if (deployNetwork) {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.42.0.0/16' ] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.42.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.42.2.0/26'
        }
      }
      {
        name: oracleSubnet
        properties: {
          addressPrefix: '10.42.3.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
      {
        name: pgSubnet
        properties: {
          addressPrefix: '10.42.4.0/24'
          delegations: [ {
            name: 'pgFlex'
            properties: { serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers' }
          } ]
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (deployWorkstation) {
  name: pipName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: dnsLabelPrefix }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = if (deployWorkstation) {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [ {
      name: 'ipconfig1'
      properties: {
        subnet: { id: '${vnet.id}/subnets/${subnetName}' }
        privateIPAllocationMethod: 'Dynamic'
        publicIPAddress: { id: pip.id }
      }
    } ]
  }
}

// PowerShell setup script, with the auto-provisioned Foundry (Azure OpenAI)
// endpoint and deployment name substituted in, plus the exact database
// connection values so the workstation writes a desktop cheat-sheet (avoids
// mistyped hostnames). Referencing these properties makes the workstation
// install wait until Foundry, PostgreSQL, and the Oracle NIC exist.
var setupScript = replace(replace(replace(replace(replace(replace(loadTextContent('setup.ps1'),
  '__FOUNDRY_ENDPOINT__',   foundryEndpoint),
  '__FOUNDRY_DEPLOYMENT__', openAiDeploymentName),
  '__PG_FQDN__',            postgresHost),
  '__ORACLE_HOST__',        oracleHost),
  '__PG_ADMIN__',           adminUsername),
  '__PG_DATABASE__',        scratchDatabaseName)

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = if (deployWorkstation) {
  name: vmName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer:     'WindowsServer'
        sku:       '2022-datacenter-azure-edition'
        version:   'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 128
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id } ] }
  }
}

// Install VS Code + PostgreSQL extension + Oracle Instant Client + Azure CLI.
// Run Command takes the PowerShell inline — no storage account, no public ports.
resource setup 'Microsoft.Compute/virtualMachines/runCommands@2024-03-01' = if (deployWorkstation) {
  parent: vm
  name: 'install-workstation'
  location: location
  properties: {
    source: { script: setupScript }
    timeoutInSeconds: 3600
    asyncExecution: false
  }
}

// Azure Bastion — private RDP access via a tunnel, no public port 22/3389.
// Standard SKU with tunneling enabled so `az network bastion tunnel` works.
// disableCopyPaste is set false so clipboard copy/paste works in the browser
// session (native RDP over the tunnel gets full clipboard from the client).
resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (deployWorkstation) {
  name: '${bastionName}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = if (deployWorkstation) {
  name: bastionName
  location: location
  sku: { name: 'Standard' }
  properties: {
    enableTunneling: true
    disableCopyPaste: false
    ipConfigurations: [ {
      name: 'IpConf'
      properties: {
        subnet: { id: '${vnet.id}/subnets/AzureBastionSubnet' }
        publicIPAddress: { id: bastionPip.id }
      }
    } ]
  }
}

// ---------------------------------------------------------------------------
// Oracle source: Ubuntu VM running Oracle Database Free 23ai in a container,
// seeded with a sample HR schema. Reachable privately on 1521 from the VNet.
// ---------------------------------------------------------------------------
resource oracleNic 'Microsoft.Network/networkInterfaces@2023-11-01' = if (deployOracle) {
  name: oracleNicName
  location: location
  properties: {
    ipConfigurations: [ {
      name: 'ipconfig1'
      properties: {
        subnet: { id: '${vnet.id}/subnets/${oracleSubnet}' }
        privateIPAllocationMethod: 'Dynamic'
      }
    } ]
  }
}

resource oracleVm 'Microsoft.Compute/virtualMachines@2024-03-01' = if (deployOracle) {
  name: oracleVmName
  location: location
  properties: {
    hardwareProfile: { vmSize: oracleVmSize }
    osProfile: {
      computerName: 'oracle-source'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(oracleCloudInit)
      linuxConfiguration: { disablePasswordAuthentication: false }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer:     'ubuntu-24_04-lts'
        sku:       'server'
        version:   'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 64
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: { networkInterfaces: [ { id: oracleNic.id } ] }
  }
  // Ensure the extension allow-list is in place before cloud-init runs
  // CREATE EXTENSION against the scratch database.
  dependsOn: [ pgExtensions, pgSandboxDb ]
}

// ---------------------------------------------------------------------------
// Scratch/target: Azure Database for PostgreSQL flexible server (private access
// integrated into the VNet, reachable on 5432 from the workstation).
// ---------------------------------------------------------------------------
resource pgDns 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployPostgres) {
  name: pgDnsZoneName
  location: 'global'
}

resource pgDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployPostgres) {
  parent: pgDns
  name: 'vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnet.id }
  }
}

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = if (deployPostgres) {
  name: pgName
  location: location
  sku: { name: pgSkuName, tier: postgresSkuTier }
  properties: {
    version: postgresVersion
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    storage: { storageSizeGB: 32 }
    network: {
      delegatedSubnetResourceId: '${vnet.id}/subnets/${pgSubnet}'
      privateDnsZoneArmResourceId: pgDns.id
    }
    highAvailability: { mode: 'Disabled' }
    backup: { backupRetentionDays: 7, geoRedundantBackup: 'Disabled' }
  }
  dependsOn: [ pgDnsLink ]
}

// Allow-list the extensions the Oracle-to-PostgreSQL Migration Wizard
// recommends, so CREATE EXTENSION is permitted in the scratch database. This
// is control-plane only; the Oracle VM's cloud-init then creates them in the DB
// (pg_cron is allow-listed but additionally needs shared_preload_libraries +
// a restart, so it is not auto-created).
resource pgExtensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = if (deployPostgres) {
  parent: postgres
  name: 'azure.extensions'
  properties: {
    value: 'ORAFCE,PG_PARTMAN,PGCRYPTO,POSTGIS,POSTGIS_TIGER_GEOCODER,POSTGIS_TOPOLOGY,PG_CRON,TABLEFUNC,UUID-OSSP,PG_TRGM,FUZZYSTRMATCH,ADDRESS_STANDARDIZER,ADDRESS_STANDARDIZER_DATA_US'
    source: 'user-override'
  }
}

// Dedicated scratch/sandbox database for the migration. The Migration Wizard
// writes converted objects here (and the Oracle VM's cloud-init creates the
// extensions in it), keeping the server's default 'postgres' database clean.
resource pgSandboxDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = if (deployPostgres) {
  parent: postgres
  name: scratchDatabaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// ---------------------------------------------------------------------------
// Microsoft Foundry: Azure OpenAI account + model deployment that powers the
// AI conversion. The workstation's managed identity is granted key-less access.
// ---------------------------------------------------------------------------
resource openai 'Microsoft.CognitiveServices/accounts@2024-10-01' = if (deployOpenAi) {
  name: openaiName
  location: location
  kind: 'OpenAI'
  sku: { name: 'S0' }
  properties: {
    customSubDomainName: openaiName
    publicNetworkAccess: 'Enabled'
  }
}

resource openaiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = if (deployOpenAi) {
  parent: openai
  name: openAiDeploymentName
  sku: { name: openAiSkuName, capacity: openAiCapacity }
  properties: {
    model: { format: 'OpenAI', name: openAiModelName, version: openAiModelVersion }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}

// Cognitive Services OpenAI User role, so the workstation can call Foundry
// with its managed identity instead of an API key.
var openAiUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
resource openaiRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployOpenAi && deployWorkstation) {
  name: guid(openai.id, vm.id, openAiUserRoleId)
  scope: openai
  properties: {
    roleDefinitionId: openAiUserRoleId
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the interactive deployer the same role, so the person running the
// Migration Wizard can authenticate to Foundry with their own Microsoft Entra
// sign-in (not only the workstation's managed identity or an API key). Without
// this, an Entra sign-in in the wizard fails with PermissionDenied because the
// user account has no role on the Azure OpenAI resource.
resource openaiRoleDeployer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployOpenAi) {
  name: guid(openai.id, deployer().objectId, openAiUserRoleId)
  scope: openai
  properties: {
    roleDefinitionId: openAiUserRoleId
    principalId: deployer().objectId
  }
}

output publicFqdn string = deployWorkstation ? pip.properties.dnsSettings.fqdn : ''
output vmResourceId string = deployWorkstation ? vm.id : ''
output bastionRdpTunnelCommand string = deployWorkstation ? 'az network bastion tunnel -n ${bastionName} -g ${resourceGroup().name} --target-resource-id ${vm.id} --resource-port 3389 --port 13389  # then RDP to localhost:13389' : ''
output oraclePrivateIp string = oracleHost
output oracleServiceName string = deployOracle ? 'FREEPDB1' : ''
output postgresFqdn string = postgresHost
output postgresAdmin string = deployPostgres ? adminUsername : ''
output postgresDatabase string = deployPostgres ? scratchDatabaseName : ''
output foundryEndpoint string = foundryEndpoint
output foundryDeployment string = deployOpenAi ? openAiDeploymentName : ''
