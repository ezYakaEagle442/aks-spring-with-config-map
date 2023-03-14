// https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming

@description('The Identity location')
param location string = resourceGroup().location

@description('A UNIQUE name')
@maxLength(21)
param appName string = 'hello${uniqueString(resourceGroup().id, subscription().id)}'

@description('The Identity Tags. See https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources?tabs=bicep#apply-an-object')
param tags object = {
  Environment: 'Dev'
  Dept: 'IT'
  Scope: 'EU'
  CostCenter: '442'
  Owner: 'Hello World'
}

///////////////////////////////////
// Resource names

// id-<app or service name>-<environment>-<region name>-<###>
// ex: id-appcn-keda-prod-eastus2-001

@description('AKS Cluster UserAssigned Managed Identity name. Character limit: 3-128 Valid characters: Alphanumerics, hyphens, and underscores')
param aksIdentityName string = 'id-aks-${appName}-cluster-dev-${location}-101'

@description('The admin-server Identity name, see Character limit: 3-128 Valid characters: Alphanumerics, hyphens, and underscores')
param helloAppIdentityName string = 'id-aks-${appName}-hello-dev-${location}-101'

///////////////////////////////////
// New resources

// https://learn.microsoft.com/en-us/azure/templates/microsoft.managedidentity/userassignedidentities?pivots=deployment-language-bicep
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: aksIdentityName
  location: location
  tags: tags
}
output aksIdentityIdentityId string = aksIdentity.id
output aksIdentityName string = aksIdentity.name
output aksIdentityPrincipalId string = aksIdentity.properties.principalId
output aksIdentityClientId string = aksIdentity.properties.clientId

resource helloAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: helloAppIdentityName
  location: location
  tags: tags
}

output helloAppIdentityId string = helloAppIdentity.id
output helloAppIdentityName string = helloAppIdentity.name
output helloAppPrincipalId string = helloAppIdentity.properties.principalId
output helloAppClientId string = helloAppIdentity.properties.clientId
