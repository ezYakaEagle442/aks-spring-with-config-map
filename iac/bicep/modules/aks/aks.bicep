// see BICEP samples at https://github.com/ssarwa/Bicep/blob/master/main.bicep
// https://github.com/brwilkinson/AzureDeploymentFramework/blob/main/ADF/bicep/AKS.bicep
@description('A UNIQUE name')
@maxLength(21)
param appName string = 'hello${uniqueString(resourceGroup().id, subscription().id)}'

@description('The location of the Managed Cluster resource.')
param location string = resourceGroup().location

@description('The name of the Managed Cluster resource.')
param clusterName string = 'aks-${appName}'

@description('The AKS Cluster SKU name. See https://learn.microsoft.com/en-us/azure/aks/free-standard-pricing-tiers')
param aksSkuName string = 'Base'

@description('The AKS Cluster SKU Tier. See https://learn.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-bicep#managedclustersku')
@allowed([
  'Free'
  'Paid'
  'Standard'
])
param aksSkuTier string = 'Free'

param sshPublicKey string

@description('IP ranges string Array allowed to call the AKS API server, specified in CIDR format, e.g. 137.117.106.88/29. see https://learn.microsoft.com/en-us/azure/aks/api-server-authorized-ip-ranges')
param authorizedIPRanges array = []
  
@description('The AKS Cluster Admin Username')
param aksAdminUserName string = '${appName}-admin'

// Preview: https://docs.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#kubernetes-version-alias-preview
@description('The AKS Cluster alias version, check with az aks get-versions --location westeurope --output table')
param k8sVersion string = '1.26.3'

@description('The SubnetID to deploy the AKS Cluster')
param subnetID string

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN.')
param dnsPrefix string = appName // 'hellospringaksconfigmap'

@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize.')
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@description('AKS Cluster UserAssigned Managed Identity name. Character limit: 3-128 Valid characters: Alphanumerics, hyphens, and underscores')
param aksIdentityName string = 'id-aks-${appName}-cluster-dev-${location}-101'

@description('The Log Analytics workspace name used by the OMS agent in the AKS Cluster')
param logAnalyticsWorkspaceName string = 'log-${appName}'

@description('The number of nodes for the cluster.')
@minValue(1)
@maxValue(12)
param agentCount int = 1

@description('The size of the Virtual Machine.')
param agentVMSize string = 'Standard_D2s_v3'

@description('The AKS cluster Managed ResourceGroup')
param nodeRG string = 'rg-MC-${appName}'

@description('Add the KEDA Add-on')
param kedaAddon bool = false
 
@description('Installs Azure Workload Identity into the cluster')
param workloadIdentity bool = false

@description('Configures the AKS cluster as an OIDC issuer for use with Workload Identity')
param oidcIssuer bool = false

@description('Rotation poll interval for the AKS KV CSI provider')
param keyVaultAksCSIPollInterval string = '2m'

@description('Enable Microsoft Defender for Containers')
param defenderForContainers bool = false

@allowed([
  ''
  'audit'
  'deny'
])
@description('Enable the Azure Policy addon')
param azurepolicy string = ''

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: aksIdentityName
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters?tabs=bicep
// https://github.com/Azure/AKS-Construction/blob/main/bicep/main.bicep
resource aks 'Microsoft.ContainerService/managedClusters@2022-10-02-preview' = {
  name: clusterName
  location: location
  sku: {
    name: aksSkuName
    tier: aksSkuTier
  }    
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  } 
  properties: {
    kubernetesVersion: k8sVersion      
    dnsPrefix: dnsPrefix
    enableRBAC: true
    agentPoolProfiles: [
      {
        availabilityZones: [
          '1'
        ]        
        name: 'agentpool'
        osDiskSizeGB: osDiskSizeGB
        enableAutoScaling: true
        count: agentCount
        minCount: 1
        maxCount: 1
        maxPods: 30
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: subnetID
        osSKU: 'CBLMariner'
      }  
    ]
    linuxProfile: {
      adminUsername: aksAdminUserName
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }  
    storageProfile: {
      diskCSIDriver: {
        enabled: true
        version: 'V1'
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
      blobCSIDriver: {
        enabled: true
      }
    }    
    apiServerAccessProfile: !empty(authorizedIPRanges) ? {
      authorizedIPRanges: authorizedIPRanges
    } :{
      enablePrivateCluster: false
      privateDNSZone: ''
      enablePrivateClusterPublicFQDN: false     
      enableVnetIntegration: false
    }      

    addonProfiles: {
      omsagent: {
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
        enabled: true
      }
      gitops: {
        enabled: false
        config: {          
        }
      }      
      
      azurepolicy: {
        enabled: !empty(azurepolicy)
        config: {
          version: !empty(azurepolicy) ? 'v2' : json('null')
        }
      }

      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation:  'true' // true
          rotationPollInterval: keyVaultAksCSIPollInterval
        }        
      }
      openServiceMesh: {
        enabled: false
        config: {}
      }
    }
    azureMonitorProfile: {
      metrics: {
        enabled: true
        /*
        kubeStateMetrics: {
          metricAnnotationsAllowList: 'string'
          metricLabelsAllowlist: 'string'
        }*/
      }
    }    
    nodeResourceGroup: nodeRG    
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    } 
    workloadAutoScalerProfile: {
      keda: {
          enabled: kedaAddon
      }
    }    
    networkProfile: {
      networkMode: 'transparent'
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      outboundType: 'loadBalancer'
      serviceCidr: '10.42.0.0/24'
      dnsServiceIP: '10.42.0.10'         
    }
    oidcIssuerProfile: {
      enabled: oidcIssuer
    }    
    securityProfile: {
      workloadIdentity: {
        enabled: workloadIdentity
      }
      defender: {
        logAnalyticsWorkspaceResourceId: defenderForContainers ? logAnalyticsWorkspace.id : null  // ERROR caused If : AzureDefender is disabled but Log Analytics workspace resource ID is not empty
        securityMonitoring: {
          enabled: defenderForContainers
        }
      }      
    }              
  }  
}

// https://github.com/Azure/azure-rest-api-specs/issues/17563
output aksId string = aks.id
output aksClusterName string = aks.name
output aksNodeResourceGroup string = aks.properties.nodeResourceGroup
output controlPlaneFQDN string = aks.properties.fqdn
output kubeletIdentity string = aks.properties.identityProfile.kubeletidentity.objectId
output keyVaultAddOnIdentity string = aks.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
output spnClientId string = aks.properties.servicePrincipalProfile.clientId

// output aksIdentityPrincipalId string = aks.identity.principalId
output aksOutboundType string = aks.properties.networkProfile.outboundType
output aksEffectiveOutboundIPs array = aks.properties.networkProfile.loadBalancerProfile.effectiveOutboundIPs
output aksManagedOutboundIPsCount int = aks.properties.networkProfile.loadBalancerProfile.managedOutboundIPs.count


resource AKSDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'AKSDiags'
  scope: aks
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'kube-audit'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: false
      }
      {
        category: 'kube-scheduler'
        enabled: false
      }
      {
        category: 'cluster-autoscaler'
        enabled: false
      }
      {
        category: 'guard'
        enabled: true
      }
    ]
    metrics: [
      {
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 7
        }
      }
    ]
  }
}
