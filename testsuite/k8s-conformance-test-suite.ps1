# Set the following environment variables to run the test suite

# Common Variables
# Some of the variables need to be populated from the service principal and storage account details provided to you by Microsoft
$connectedClustedId=-join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 7 |%{[char]$_})
$AZ_TENANT_ID=8548a469-8c0e-4aa4-b534-ac75ca1e02f7       # tenant field of the service principal
$AZ_SUBSCRIPTION_ID=3959ec86-5353-4b0c-b5d7-3877122861a0 # subscription id of the azure subscription (will be provided)
$AZ_CLIENT_ID=dedc1151-fef0-4911-839b-8414f7d06eb0       # appid field of the service principal
$AZ_OBJECT_ID=36d14979-cf18-4987-921f-2bb75c1fb247       # objectid of the service principal, please add it within the quotes
$AZ_CLIENT_SECRET=VlAXa3bc4n-l2d~ERAWUePzzd84v--ucxs     # password field of the service principal
$AZ_STORAGE_ACCOUNT=vmwarearcsa                          # name of your storage account
$AZ_STORAGE_ACCOUNT_SAS="?sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-12T00%3A55%3A51Z&se=2022-08-13T00%3A55%3A00Z&sp=rwlacu&sig=2kXRIzyXmlwbP92BtLrrLMrdfb96MKZR7TRWxytcanc%3D" # sas token for your storage account, please add it within the quotes
$RESOURCE_GROUP=external-vmware                          # resource group name; set this to the resource group
$OFFERING_NAME=TKGm-v1.5.1                # name of the partner offering; use this variable to distinguish between the results tar for different offerings
$CLUSTERNAME=arc-partner-test-$connectedClustedId        # name of the arc connected cluster
$LOCATION=eastus                                         # location of the arc connected cluster

# Platform Cleanup Plugin
$CLEANUP_TIMEOUT=1500 # time in seconds after which the platform cleanup plugin times out

# In case your cluster is behind an outbound proxy, please add the following environment variables in the below command
# --plugin-env azure-arc-platform.HTTPS_PROXY="http://<proxy ip>:<proxy port>"
# --plugin-env azure-arc-platform.HTTP_PROXY="http://<proxy ip>:<proxy port>"
# --plugin-env azure-arc-platform.NO_PROXY="kubernetes.default.svc,<ip CIDR etc>"

# In case your outbound proxy is setup with certificate authentication, follow the below steps:
# Create a Kubernetes generic secret with the name sonobuoy-proxy-cert with key proxycert in any namespace:
# kubectl create secret generic sonobuoy-proxy-cert --from-file=proxycert=<path-to-cert-file>
# By default we check for the secret in the default namespace. In case you have created the secret in some other namespace, please add the following variables in the sonobuoy run command:
# --plugin-env azure-arc-platform.PROXY_CERT_NAMESPACE="<namespace of sonobuoy secret>"
# --plugin-env azure-arc-agent-cleanup.PROXY_CERT_NAMESPACE="namespace of sonobuoy secret"

az login --service-principal --username $AZ_CLIENT_ID --password $AZ_CLIENT_SECRET --tenant $AZ_TENANT_ID
az account set -s $AZ_SUBSCRIPTION_ID


$arc_platform_version =  Get-Content -Path @("aak8sSupportPolicy.txt")

foreach($version in $arc_platform_version)
{
    Write-Host "Running the test suite for Arc for Kubernetes version: ${version}"

    sonobuoy run --wait `
    --plugin arc-k8s-platform/platform.yaml `
    --plugin-env azure-arc-platform.TENANT_ID=$AZ_TENANT_ID `
    --plugin-env azure-arc-platform.SUBSCRIPTION_ID=$AZ_SUBSCRIPTION_ID `
    --plugin-env azure-arc-platform.RESOURCE_GROUP=$RESOURCE_GROUP `
    --plugin-env azure-arc-platform.CLUSTER_NAME=$CLUSTERNAME `
    --plugin-env azure-arc-platform.LOCATION=$LOCATION `
    --plugin-env azure-arc-platform.CLIENT_ID=$AZ_CLIENT_ID `
    --plugin-env azure-arc-platform.CLIENT_SECRET=$AZ_CLIENT_SECRET `
    --plugin arc-k8s-platform/cleanup.yaml `
    --plugin-env azure-arc-platform.HELMREGISTRY=mcr.microsoft.com/azurearck8s/batch1/stable/azure-arc-k8sagents:$version `
    --plugin-env azure-arc-agent-cleanup.TENANT_ID=$AZ_TENANT_ID `
    --plugin-env azure-arc-agent-cleanup.SUBSCRIPTION_ID=$AZ_SUBSCRIPTION_ID `
    --plugin-env azure-arc-agent-cleanup.RESOURCE_GROUP=$RESOURCE_GROUP `
    --plugin-env azure-arc-agent-cleanup.CLUSTER_NAME=$CLUSTERNAME `
    --plugin-env azure-arc-agent-cleanup.CLEANUP_TIMEOUT=$CLEANUP_TIMEOUT `
    --plugin-env azure-arc-agent-cleanup.CLIENT_ID=$AZ_CLIENT_ID `
    --plugin-env azure-arc-agent-cleanup.CLIENT_SECRET=$AZ_CLIENT_SECRET `
    --plugin-env azure-arc-platform.OBJECT_ID=$AZ_OBJECT_ID `
    --config config.json

    Write-Host "Test execution completed..Retrieving results"

    $sonobuoyResults=$(sonobuoy retrieve)

    sonobuoy results $sonobuoyResults

    New-Item -Path . -Name "testResult" -ItemType "directory"
    python arc-k8s-platform/remove-secrets.py $sonobuoyResults testResult

    Remove-Item .\testResult -Recurse

    New-Item -Path . -Name "results" -ItemType "directory"
    Move-Item -Path $sonobuoyResults -Destination results\$sonobuoyResults

    Copy-Item .\partner-metadata.md  -Destination results\partner-metadata.md

    tar -czvf conformance-results-$version.tar.gz results

    Remove-Item .\results -Recurse

    Write-Host "Publishing results.."

    $versionArry=$version.Split(".")

    $containerString="conformance-results-major-"+$versionArry[0]+"-minor-"+$versionArry[1]+"-patch-"+$versionArry[2]

    az storage container create -n $containerString --account-name $AZ_STORAGE_ACCOUNT --sas-token $AZ_STORAGE_ACCOUNT_SAS
    az storage blob upload  --file conformance-results-$version.tar.gz --name conformance-results-$OFFERING_NAME.tar.gz --container-name $containerString --account-name $AZ_STORAGE_ACCOUNT --sas-token $AZ_STORAGE_ACCOUNT_SAS

    Write-Host "Cleaning the cluster.."
    sonobuoy delete --wait

    Write-Host "Buffer wait 5 minutes.."
    Start-Sleep -s 300
}
