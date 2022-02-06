
#!/bin/bash

################
# Deploy the API
################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Check for a valid command line parameter
#
API_TECH="$1"
if [ "$API_TECH" != 'nodejs' ] && [ "$API_TECH" != 'netcore' ] && [ "$API_TECH" != 'java' ]; then
  echo 'An invalid API_TECH parameter was supplied'
  exit 1
fi

#
# Copy configuration into an api.config.json file
#
if [ "$API_TECH" == 'nodejs' ]; then
  cp nodejs.config.json api.config.json
elif [ "$API_TECH" == 'netcore' ]; then
  cp netcore.config.json api.config.json
elif [ "$API_TECH" == 'java' ]; then
  cp java.config.json api.config.json
fi

#
# Create a configmap for the API's JSON configuration file
#
kubectl -n deployed delete configmap api-config 2>/dev/null
kubectl -n deployed create configmap api-config --from-file=../finalapi-scripts/api.config.json
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the API configmap'
  exit 1
fi

#
# Create a secret for the private key password of the certificate file cert-manager will create
#
kubectl -n deployed delete secret finalapi-pkcs12-password 2>/dev/null
kubectl -n deployed create secret generic finalapi-pkcs12-password --from-literal=password='Password1'
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the API certificate secret'
  exit 1
fi

#
# Trigger deployment of the API to the Kubernetes cluster
#
kubectl -n deployed delete -f api.yaml 2>/dev/null
kubectl -n deployed apply  -f api.yaml
if [ $? -ne 0 ]; then
  echo '*** API Kubernetes deployment problem encountered'
  exit 1
fi
