@description('A UNIQUE name')
@maxLength(21)
param appName string = 'hello${uniqueString(resourceGroup().id, subscription().id)}'

// https://docs.microsoft.com/en-us/rest/api/containerregistry/registries/check-name-availability
@description('The name of the ACR, must be UNIQUE. The name must contain only alphanumeric characters, be globally unique, and between 5 and 50 characters in length.')
param acrName string = 'acr${appName}'

@description('The ACR location')
param location string = resourceGroup().location

resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    adminUserEnabled: false
    dataEndpointEnabled: false // data endpoint rule is not supported for the SKU Basic
  
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

output acrId string = acr.id
output acrName string = acr.name
output acrIdentity string = acr.identity.principalId
output acrType string = acr.type
output acrRegistryUrl string = acr.properties.loginServer

// outputs-should-not-contain-secrets
// output acrRegistryUsr string = acr.listCredentials().username
//output acrRegistryPwd string = acr.listCredentials().passwords[0].value
