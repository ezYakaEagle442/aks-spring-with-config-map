@maxLength(21)
param appName string = 'hello${uniqueString(resourceGroup().id, subscription().id)}'

param location string = resourceGroup().location
param dnsPrefix string = 'hellospringaksconfigmap'
param clusterName string = 'aks-${appName}'
param aksVersion string = '1.24.6'
param vnetName string = 'vnet-aks'

@description('AKS Cluster UserAssigned Managed Identity name. Character limit: 3-128 Valid characters: Alphanumerics, hyphens, and underscores')
param aksIdentityName string = 'id-aks-${appName}-cluster-dev-${location}-101'

@description('The AKS SSH public key')
@secure()
param sshPublicKey string

@description('IP ranges string Array allowed to call the AKS API server, specified in CIDR format, e.g. 137.117.106.88/29. see https://learn.microsoft.com/en-us/azure/aks/api-server-authorized-ip-ranges')
param authorizedIPRanges array = []

// https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-secrets
module prereq './pre-req.bicep' = {
  name: 'pre-req'
  params: {
    appName: appName
    location: location
  }
}

output vnetId string = prereq.outputs.vnetId
output vnetName string = prereq.outputs.vnetName
output aksSubnetId string = prereq.outputs.aksSubnetId
output acrId string = prereq.outputs.acrId
output acrName string = prereq.outputs.acrName
output acrLoginServer string = prereq.outputs.acrLoginServer
output aksIdentityId string = prereq.outputs.aksIdentityId
output aksIdentityPrincipalId string = prereq.outputs.aksIdentityPrincipalId
output logAnalyticsWorkspaceName string = prereq.outputs.logAnalyticsWorkspaceName
output appInsightsName string = prereq.outputs.appInsightsName
output appInsightsConnectionString string = prereq.outputs.appInsightsConnectionString

// https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-secrets
module aks './modules/aks/aks.bicep' = {
  name: 'aks'
  // scope: resourceGroup(rg.name)
  params: {
    appName: appName
    clusterName: clusterName
    k8sVersion: aksVersion
    location: location
    subnetID: prereq.outputs.aksSubnetId
    dnsPrefix: dnsPrefix
    aksIdentityName: aksIdentityName
    sshPublicKey: sshPublicKey
    authorizedIPRanges: authorizedIPRanges
  }
  dependsOn: [
    prereq
  ]
}

output controlPlaneFQDN string = aks.outputs.controlPlaneFQDN
// https://github.com/Azure/azure-rest-api-specs/issues/17563
output kubeletIdentity string = aks.outputs.kubeletIdentity
output keyVaultAddOnIdentity string = aks.outputs.keyVaultAddOnIdentity
output spnClientId string = aks.outputs.spnClientId
output aksId string = aks.outputs.aksId
output aksClusterName string = aks.name
output aksOutboundType string = aks.outputs.aksOutboundType
// The default number of managed outbound public IPs is 1.
// https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard#scale-the-number-of-managed-outbound-public-ips
output aksEffectiveOutboundIPs array = aks.outputs.aksEffectiveOutboundIPs
output aksManagedOutboundIPsCount int = aks.outputs.aksManagedOutboundIPsCount


module attachacr './modules/aks/attach-acr.bicep' = {
  name: 'attach-acr'
  params: {
    appName: appName
    acrName: prereq.outputs.acrName
    aksClusterPrincipalId: aks.outputs.kubeletIdentity
  }
  dependsOn: [
    aks
  ]
}
