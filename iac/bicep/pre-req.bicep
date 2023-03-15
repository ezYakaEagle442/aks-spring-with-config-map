// Check the REST API : https://learn.microsoft.com/en-us/rest/api/aks/managed-clusters

@maxLength(21)
param appName string = 'hello${uniqueString(resourceGroup().id, subscription().id)}'
param location string = resourceGroup().location
param acrName string = 'acr${appName}'

@description('The Log Analytics workspace name used by the AKS cluster')
param logAnalyticsWorkspaceName string = 'log-${appName}'

param appInsightsName string = 'appi-${appName}'

param vnetName string = 'vnet-aks'
param vnetCidr string = '172.16.0.0/16'
param aksSubnetCidr string = '172.16.1.0/24'
param aksSubnetName string = 'snet-aks'



@description('AKS Cluster UserAssigned Managed Identity name. Character limit: 3-128 Valid characters: Alphanumerics, hyphens, and underscores')
param aksIdentityName string = 'id-aks-${appName}-cluster-dev-${location}-101'

// https://docs.microsoft.com/en-us/azure/templates/microsoft.operationalinsights/workspaces?tabs=bicep
resource logAnalyticsWorkspace  'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}
output logAnalyticsWorkspaceResourceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceCustomerId string = logAnalyticsWorkspace.properties.customerId

// https://docs.microsoft.com/en-us/azure/templates/microsoft.insights/components?tabs=bicep
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: { 
    Application_Type: 'web'
    //Flow_Type: 'Bluefield'    
    //ImmediatePurgeDataOn30Days: true // "ImmediatePurgeDataOn30Days cannot be set on current api-version"
    //RetentionInDays: 30
    IngestionMode: 'LogAnalytics' // Cannot set ApplicationInsightsWithDiagnosticSettings as IngestionMode on consolidated application 
    Request_Source: 'rest'
    SamplingPercentage: 20
    WorkspaceResourceId: logAnalyticsWorkspace.id    
  }
}
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
// output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

module ACR './modules/aks/acr.bicep' = {
  name: 'acr'
  params: {
    appName: appName
    acrName: acrName
    location: location
  }
}
output acrId string = ACR.outputs.acrId
output acrName string = ACR.outputs.acrName
output acrLoginServer string = ACR.outputs.acrRegistryUrl


module identities './modules/aks/identity.bicep' = {
  name: 'aks-identities'
  params: {
    location: location
    appName: appName
    aksIdentityName: aksIdentityName
  }
}

output aksIdentityId string = identities.outputs.aksIdentityClientId
output aksIdentityPrincipalId string = identities.outputs.aksIdentityPrincipalId
output identityName string = identities.outputs.aksIdentityName
output identityId string = identities.outputs.aksIdentityIdentityId

module vnet './modules/aks/vnet.bicep' = {
  name: 'vnet-aks'
  // scope: resourceGroup(rg.name)
  params: {
    location: location
     vnetName: vnetName
     aksSubnetName: aksSubnetName
     vnetCidr: vnetCidr
     aksSubnetCidr: aksSubnetCidr
  }   
}

output vnetId string = vnet.outputs.vnetId
output vnetName string = vnet.outputs.vnetName
output aksSubnetId string = vnet.outputs.aksSubnetId


// https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scope-extension-resources
module roleAssignments './modules/aks/roleAssignments.bicep' = {
  name: 'role-assignments'
  params: {
    aksClusterPrincipalId: identities.outputs.aksIdentityPrincipalId
    networkRoleType: 'NetworkContributor'
    vnetName: vnetName
    subnetName: aksSubnetName
  }
  dependsOn: [
    ACR
  ]
}
