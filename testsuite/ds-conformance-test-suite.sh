# Set the following environment variables to run the test suite

# Common Variables
# Some of the variables need to be populated from the service principal and storage account details provided to you by Microsoft
AZ_TENANT_ID=8548a469-8c0e-4aa4-b534-ac75ca1e02f7       # tenant field of the service principal
AZ_SUBSCRIPTION_ID=3959ec86-5353-4b0c-b5d7-3877122861a0 # subscription id of the azure subscription (will be provided)
AZ_CLIENT_ID=dedc1151-fef0-4911-839b-8414f7d06eb0       # appid field of the service principal
AZ_CLIENT_SECRET=VlAXa3bc4n-l2d~ERAWUePzzd84v--ucxs     # password field of the service principal
AZ_STORAGE_ACCOUNT=vmwaredssa                           # name of your storage account
# SharedAccessSignature=sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-11T18%3A32%3A08Z&se=2022-08-12T18%3A32%3A00Z&sp=rwlacu&sig=7vYidR48JU9fca4brBZenZanFB0nwRrF0L07IOttEMI%3D;BlobEndpoint=https://vmwaredssa.blob.core.windows.net/;FileEndpoint=https://vmwaredssa.file.core.windows.net/;QueueEndpoint=https://vmwaredssa.queue.core.windows.net/;TableEndpoint=https://vmwaredssa.table.core.windows.net/;
# ?sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-11T18%3A32%3A08Z&se=2022-08-12T18%3A32%3A00Z&sp=rwlacu&sig=7vYidR48JU9fca4brBZenZanFB0nwRrF0L07IOttEMI%3D
AZ_STORAGE_ACCOUNT_SAS="?sv=2020-04-08&ss=btqf&srt=sco&st=2021-08-11T18%3A32%3A08Z&se=2022-08-12T18%3A32%3A00Z&sp=rwlacu&sig=7vYidR48JU9fca4brBZenZanFB0nwRrF0L07IOttEMI%3D" # sas token for your storage account, please add it within the quotes
RESOURCE_GROUP=external-vmware                          # resource group name; set this to the resource group
OFFERING_NAME=TKGm-v1.2.1                 # name of the partner offering; use this variable to distinguish between the results tar for different offerings
LOCATION=eastus                                         # location of the arc connected cluster
NAMESPACE=arc-ds-controller                             # namespace of the data controller
DATA_CONTROLLER_STORAGE_CLASS=default # choose the storage class for data controller
SQL_MI_STORAGE_CLASS=default # choose the storage class for sql mi
CONFIG_PROFILE=azure-arc-aks-default-storage            # choose the config profile
AZDATA_USERNAME=azureuser                               # database username
AZDATA_PASSWORD=Welcome1234%                            # database password
SQL_INSTANCE_NAME=arc-sql                               # sql instance name
INFRASTRUCTURE=azure                                    # Allowed values are alibaba, aws, azure, gpc, onpremises, other.

# In case your cluster is behind an outbound proxy, please add the following environment variables in the below command
# --plugin-env azure-arc-ds-platform.HTTPS_PROXY="http://<proxy ip>:<proxy port>"
# --plugin-env azure-arc-ds-platform.HTTP_PROXY="http://<proxy ip>:<proxy port>"
# --plugin-env azure-arc-ds-platform.NO_PROXY="kubernetes.default.svc,<ip CIDR etc>"

# In case your outbound proxy is setup with certificate authentication, follow the below steps:
# Create a Kubernetes generic secret with the name sonobuoy-proxy-cert with key proxycert in any namespace:
# kubectl create secret generic sonobuoy-proxy-cert --from-file=proxycert=<path-to-cert-file>
# By default we check for the secret in the default namespace. In case you have created the secret in some other namespace, please add the following variables in the sonobuoy run command: 
# --plugin-env azure-arc-ds-platform.PROXY_CERT_NAMESPACE="<namespace of sonobuoy secret>"

echo "Running the test suite.."

#--kubeconfig ../../tkg-1.2.1-arc-ds.kubeconfig

sonobuoy run --wait --level debug \
--plugin arc-dataservices/dataservices.yaml \
--plugin-env azure-arc-ds-platform.NAMESPACE=$NAMESPACE \
--plugin-env azure-arc-ds-platform.DATA_CONTROLLER_STORAGE_CLASS=$DATA_CONTROLLER_STORAGE_CLASS \
--plugin-env azure-arc-ds-platform.SQL_MI_STORAGE_CLASS=$SQL_MI_STORAGE_CLASS \
--plugin-env azure-arc-ds-platform.CONFIG_PROFILE=$CONFIG_PROFILE \
--plugin-env azure-arc-ds-platform.AZDATA_USERNAME=$AZDATA_USERNAME \
--plugin-env azure-arc-ds-platform.AZDATA_PASSWORD=$AZDATA_PASSWORD \
--plugin-env azure-arc-ds-platform.SQL_INSTANCE_NAME=$SQL_INSTANCE_NAME \
--plugin-env azure-arc-ds-platform.TENANT_ID=$AZ_TENANT_ID \
--plugin-env azure-arc-ds-platform.SUBSCRIPTION_ID=$AZ_SUBSCRIPTION_ID \
--plugin-env azure-arc-ds-platform.RESOURCE_GROUP=$RESOURCE_GROUP \
--plugin-env azure-arc-ds-platform.LOCATION=$LOCATION \
--plugin-env azure-arc-ds-platform.CLIENT_ID=$AZ_CLIENT_ID \
--plugin-env azure-arc-ds-platform.CLIENT_SECRET=$AZ_CLIENT_SECRET \
--plugin-env azure-arc-ds-platform.INFRASTRUCTURE=$INFRASTRUCTURE \
--sonobuoy-image harbor-repo.vmware.com/dockerhub-proxy-cache/sonobuoy/sonobuoy:v0.53.2 \

# On `sonobuoy run` when passing a `--kubeconfig` it seems `--sonobuoy-image` is ignored, thus defaults to docker.io (rather than using harbor-repo.vmware.com), which of course results in `429 Too Many Requests - Server message: toomanyrequests: You have reached your pull rate limit.`

status=$(sonobuoy status)

echo $status

echo "Test execution completed..Retrieving results"

sonobuoyResults=$(sonobuoy retrieve)
echo $sonobuoyResults

# sonobuoy results $sonobuoyResults
# mkdir results
# mv $sonobuoyResults results/$sonobuoyResults
# cp partner-metadata.md results/partner-metadata.md
# tar -czvf ds-conformance-results-$OFFERING_NAME.tar.gz results

# rm -rf results

# echo "Publishing results.."

# az login --service-principal --username $AZ_CLIENT_ID --password $AZ_CLIENT_SECRET --tenant $AZ_TENANT_ID
# az account set -s $AZ_SUBSCRIPTION_ID

# az storage container create -n conformance-results --account-name $AZ_STORAGE_ACCOUNT --sas-token $AZ_STORAGE_ACCOUNT_SAS
# az storage blob upload --socket-timeout 3600 --file ds-conformance-results-$OFFERING_NAME.tar.gz --name conformance-results-$OFFERING_NAME.tar.gz --container-name conformance-results --account-name $AZ_STORAGE_ACCOUNT --sas-token $AZ_STORAGE_ACCOUNT_SAS
