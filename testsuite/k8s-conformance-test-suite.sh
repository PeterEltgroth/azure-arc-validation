# Set the following environment variables to run the test suite

# Common Variables
# Some of the variables need to be populated from the service principal and storage account details provided to you by Microsoft
connectedClustedId=$(uuid | tr -dc A-Za-z0-9 | head -c 7)   #$(tr -dc A-Za-z0-9 </dev/urandom | head -c 7 ; echo '')
AZ_TENANT_ID=8548a469-8c0e-4aa4-b534-ac75ca1e02f7       # tenant field of the service principal
AZ_SUBSCRIPTION_ID=3959ec86-5353-4b0c-b5d7-3877122861a0 # subscription id of the azure subscription (will be provided)
AZ_CLIENT_ID=dedc1151-fef0-4911-839b-8414f7d06eb0       # appid field of the service principal
AZ_CLIENT_SECRET=VlAXa3bc4n-l2d~ERAWUePzzd84v--ucxs     # password field of the service principal
AZ_STORAGE_ACCOUNT=vmwarearcsa                          # name of your storage account
# First
# SharedAccessSignature=sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-11T18%3A42%3A20Z&se=2022-08-12T18%3A42%3A00Z&sp=rwlacu&sig=SziNS6POMRzkRzmKRK9tEUwwIkZ6KFLEWkAwve2t8o0%3D;BlobEndpoint=https://vmwarearcsa.blob.core.windows.net/;FileEndpoint=https://vmwarearcsa.file.core.windows.net/;QueueEndpoint=https://vmwarearcsa.queue.core.windows.net/;TableEndpoint=https://vmwarearcsa.table.core.windows.net/;
# ?sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-11T18%3A42%3A20Z&se=2022-08-12T18%3A42%3A00Z&sp=rwlacu&sig=SziNS6POMRzkRzmKRK9tEUwwIkZ6KFLEWkAwve2t8o0%3D
# Newer
# SharedAccessSignature=sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-12T00%3A55%3A51Z&se=2022-08-13T00%3A55%3A00Z&sp=rwlacu&sig=2kXRIzyXmlwbP92BtLrrLMrdfb96MKZR7TRWxytcanc%3D;BlobEndpoint=https://vmwarearcsa.blob.core.windows.net/;FileEndpoint=https://vmwarearcsa.file.core.windows.net/;QueueEndpoint=https://vmwarearcsa.queue.core.windows.net/;TableEndpoint=https://vmwarearcsa.table.core.windows.net/;
# ?sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-12T00%3A55%3A51Z&se=2022-08-13T00%3A55%3A00Z&sp=rwlacu&sig=2kXRIzyXmlwbP92BtLrrLMrdfb96MKZR7TRWxytcanc%3D
AZ_STORAGE_ACCOUNT_SAS="?sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-12T00%3A55%3A51Z&se=2022-08-13T00%3A55%3A00Z&sp=rwlacu&sig=2kXRIzyXmlwbP92BtLrrLMrdfb96MKZR7TRWxytcanc%3D" # sas token for your storage account, please add it within the quotes
ARC_PLATFORM_VERSION=1.3.8                              # version of Arc for K8s platform to be installed
RESOURCE_GROUP=external-vmware                          # resource group name; set this to the resource group
OFFERING_NAME=TKGm-v1.2.1                # name of the partner offering; use this variable to distinguish between the results tar for different offerings
CLUSTERNAME=arc-partner-test-$connectedClustedId        # name of the arc connected cluster
LOCATION=eastus                                         # location of the arc connected cluster

# Platform Cleanup Plugin
CLEANUP_TIMEOUT=1500 # time in seconds after which the platform cleanup plugin times out

echo "Running the test suite.."

sonobuoy run --wait \
--plugin arc-k8s-platform/platform.yaml \
--plugin-env azure-arc-platform.TENANT_ID=$AZ_TENANT_ID \
--plugin-env azure-arc-platform.SUBSCRIPTION_ID=$AZ_SUBSCRIPTION_ID \
--plugin-env azure-arc-platform.RESOURCE_GROUP=$RESOURCE_GROUP \
--plugin-env azure-arc-platform.CLUSTER_NAME=$CLUSTERNAME \
--plugin-env azure-arc-platform.LOCATION=$LOCATION \
--plugin-env azure-arc-platform.CLIENT_ID=$AZ_CLIENT_ID \
--plugin-env azure-arc-platform.CLIENT_SECRET=$AZ_CLIENT_SECRET \
--plugin-env azure-arc-platform.HELMREGISTRY=mcr.microsoft.com/azurearck8s/batch1/stable/azure-arc-k8sagents:$ARC_PLATFORM_VERSION \
--plugin arc-k8s-platform/cleanup.yaml \
--plugin-env azure-arc-agent-cleanup.TENANT_ID=$AZ_TENANT_ID \
--plugin-env azure-arc-agent-cleanup.SUBSCRIPTION_ID=$AZ_SUBSCRIPTION_ID \
--plugin-env azure-arc-agent-cleanup.RESOURCE_GROUP=$RESOURCE_GROUP \
--plugin-env azure-arc-agent-cleanup.CLUSTER_NAME=$CLUSTERNAME \
--plugin-env azure-arc-agent-cleanup.CLEANUP_TIMEOUT=$CLEANUP_TIMEOUT \
--plugin-env azure-arc-agent-cleanup.CLIENT_ID=$AZ_CLIENT_ID \
--plugin-env azure-arc-agent-cleanup.CLIENT_SECRET=$AZ_CLIENT_SECRET \
--sonobuoy-image harbor-repo.vmware.com/dockerhub-proxy-cache/sonobuoy/sonobuoy:v0.53.2 \
# projects.registry.vmware.com/sonobuoy/sonobuoy@sha256:bc83d32640e39aed2aa631387dd9ffde46e89879d3eb85208db737b73abb8b85
echo "Test execution completed..Retrieving results"

sonobuoyResults=$(sonobuoy retrieve)
sonobuoy results $sonobuoyResults
mkdir results
mv $sonobuoyResults results/$sonobuoyResults
cp partner-metadata.md results/partner-metadata.md
tar -czvf k8s-conformance-results-$ARC_PLATFORM_VERSION-$OFFERING_NAME.tar.gz results
rm -rf results

echo "Publishing results.."

az login --service-principal --username $AZ_CLIENT_ID --password $AZ_CLIENT_SECRET --tenant $AZ_TENANT_ID
az account set -s $AZ_SUBSCRIPTION_ID

az storage container create -n conformance-results --account-name $AZ_STORAGE_ACCOUNT --sas-token $AZ_STORAGE_ACCOUNT_SAS
az storage blob upload --file k8s-conformance-results-$ARC_PLATFORM_VERSION-$OFFERING_NAME.tar.gz --name conformance-results-$ARC_PLATFORM_VERSION-$OFFERING_NAME.tar.gz --container-name conformance-results --account-name $AZ_STORAGE_ACCOUNT --sas-token $AZ_STORAGE_ACCOUNT_SAS
