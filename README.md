# aks-spring-withconfig-map
Spring Boot App deployed to AKS using a ConfigMap instead of the Spring-Config-Server



```bash
LOCATION="francecentral"
RG_APP="rg-hello-aks-cm"

az group create --name $RG_APP --location $LOCATION

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

az feature list --output table --namespace Microsoft.ContainerService
az feature register --namespace "Microsoft.ContainerService" --name "AKS-GitOps"
az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-Dapr"
az feature register --namespace "Microsoft.ContainerService" --name "EnableAzureKeyvaultSecretsProvider"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-AzureDefender"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-PrometheusAddonPreview" 
az feature register --namespace "Microsoft.ContainerService" --name "AutoUpgradePreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-OMSAppMonitoring"
az feature register --namespace "Microsoft.ContainerService" --name "ManagedCluster"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-AzurePolicyAutoApprove"
az feature register --namespace "Microsoft.ContainerService" --name "FleetResourcePreview"

az provider list --output table
az provider list --query "[?registrationState=='Registered']" --output table
az provider list --query "[?namespace=='Microsoft.KeyVault']" --output table
az provider list --query "[?namespace=='Microsoft.OperationsManagement']" --output table

az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.OperationalInsights 
az provider register --namespace Microsoft.DBforMySQL
az provider register --namespace Microsoft.DBforPostgreSQL
az provider register --namespace Microsoft.Compute 
az provider register --namespace Microsoft.AppConfiguration       
az provider register --namespace Microsoft.AppPlatform
az provider register --namespace Microsoft.EventHub  
az provider register --namespace Microsoft.Kubernetes 
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.Kusto  
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.Monitor
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.Network  

az provider register --namespace Microsoft.ServiceBus
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Subscription

# https://learn.microsoft.com/en-us/azure/aks/cluster-extensions
az extension add --name k8s-extension
az extension update --name k8s-extension

# https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2?
az extension add -n k8s-configuration


export ssh_key=aksadm
echo -e 'y' | ssh-keygen -t rsa -b 4096 -f ~/.ssh/$ssh_key -C "youremail@groland.grd"

sshPublicKey=`cat /home/pinpin/.ssh/$ssh_key.pub`
az deployment group create --name hello-spring -f ./iac/bicep/main.bicep -g rg-hello-aks-cm  \
-p appName=hello42 -p location=francecentral \
-p sshPublicKey="$sshPublicKey" # https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli#inline-parameters 

REGISTRY_URL=$(az deployment group show --name acr -g $RG_APP --query properties.outputs.acrRegistryUrl.value -o tsv)
echo "REGISTRY_URL="$REGISTRY_URL

CONTAINER_REGISTRY=$(az deployment group show --name acr -g $RG_APP --query properties.outputs.acrName.value -o tsv)
echo "CONTAINER_REGISTRY="$CONTAINER_REGISTRY

AKS_CLUSTER_NAME=$(az deployment group show --name aks -g $RG_APP --query properties.outputs.aksClusterName.value -o tsv)
echo "AKS_CLUSTER_NAME="$AKS_CLUSTER_NAME


az aks get-credentials --name $AKS_CLUSTER_NAME -g $RG_APP
kubectl  cluster-info

mkdir k8s/deploy

# image: ${CONTAINER_REGISTRY}.azurecr.io/${REPO}/hello-service:${IMAGE_TAG}
DOCKERFILE_PATH="src/main/docker/Dockerfile"
REPOSITORY="hello"
IMAGE_TAG=

# https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli?tabs=azure-cli
# tag_id=$(docker build --build-arg --no-cache -t "test-v0.0.1" . 2>/dev/null | awk '/Successfully built/{print $NF}')

tag_id=$(docker build --build-arg --no-cache -t $REGISTRY_URL/$REPOSITORY/hello-service:v0.1.42 -f $DOCKERFILE_PATH . 2>/dev/null | awk '/Successfully built/{print $NF}')
docker tag $REGISTRY_URL/$REPOSITORY/hello-service:$tag_id $REGISTRY_URL/$REPOSITORY/hello-service:latest
docker push "$REGISTRY_URL/$REPOSITORY/hello-service:latest"
docker push "$REGISTRY_URL/$REPOSITORY/hello-service:$tag_id"

envsubst < k8s/hello-deployment.yaml > k8s/deploy/hello-deployment.yaml
envsubst < k8s/hello-ingress.yaml > k8s/deploy/hello-ingress.yaml 
envsubst < k8s/hello-service.yaml > k8s/deploy/hello-service.yaml 

kubectl apply -f k8s/deploy/hello-deployment.yaml
kubectl apply -f k8s/deploy/hello-ingress.yaml
kubectl apply -f k8s/deploy/hello-service.yaml


GIT_CFG_URL=https://raw.githubusercontent.com/ezYakaEagle442/aks-cfg-srv/main

CONFIG_MAP_DIR=configmap
mkdir $CONFIG_MAP_DIR
ls -al $CONFIG_MAP_DIR

wget $GIT_CFG_URL/api-gateway.yml -O $CONFIG_MAP_DIR/api-gateway.yml
wget $GIT_CFG_URL/application-mysql.yml -O $CONFIG_MAP_DIR/application-mysql.yml
wget $GIT_CFG_URL/application.yml -O $CONFIG_MAP_DIR/application.yml
wget $GIT_CFG_URL/customers-service.yml -O $CONFIG_MAP_DIR/customers-service.yml
wget $GIT_CFG_URL/vets-service.yml -O $CONFIG_MAP_DIR/vets-service.yml
wget $GIT_CFG_URL/visits-service.yml -O $CONFIG_MAP_DIR/visits-service.yml

echo "About to generate the ConfigMap Manifest ..."

# You can use kubectl create configmap to create a ConfigMap from multiple files in the same directory. 
# When you are creating a ConfigMap based on a directory, kubectl identifies files whose filename is a valid key in the directory
# and packages each of those files into the new ConfigMap

kubectl create configmap spring-app-config --from-file=$CONFIG_MAP_DIR --dry-run=client -o yaml > spring-app-config.yaml
# immutable: true ==> https://kubernetes.io/docs/concepts/configuration/configmap/#configmap-immutable

ls -al $CONFIG_MAP_DIR
kubectl apply -f spring-app-config.yaml


```

## K8S Tips


```sh
  source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
  echo "source <(kubectl completion bash)" >> ~/.bashrc 
  alias k=kubectl
  complete -F __start_kubectl k

  alias kn='kubectl config set-context --current --namespace '

  export gen="--dry-run=client -o yaml"

  alias kp="kubectl get pods -o wide"
  alias kd="kubectl get deployment -o wide"
  alias ks="kubectl get svc -o wide"
  alias kno="kubectl get nodes -o wide"

  alias kdp="kubectl describe pod"
  alias kdd="kubectl describe deployment"
  alias kds="kubectl describe service"

  vi ~/.vimrc
  set ts=2 sw=2
  . ~/.vimrc
``

