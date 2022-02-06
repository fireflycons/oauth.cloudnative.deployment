
#!/bin/bash

##########################
# Deploy the Token Handler
##########################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Create a configmap for the token handler's JSON configuration file
#
kubectl -n deployed delete configmap tokenhandler-config 2>/dev/null
kubectl -n deployed create configmap tokenhandler-config --from-file=../tokenhandler-scripts/api.config.json
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Token Handler configmap'
  exit 1
fi

#
# Create a secret for the private key password of the certificate file cert-manager will create
#
kubectl -n deployed delete secret tokenhandler-pkcs12-password 2>/dev/null
kubectl -n deployed create secret generic tokenhandler-pkcs12-password --from-literal=password='Password1'
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Token Handler certificate secret'
  exit 1
fi

#
# Trigger deployment of the token handler to the Kubernetes cluster
#
kubectl -n deployed delete -f api.yaml 2>/dev/null
kubectl -n deployed apply  -f api.yaml
if [ $? -ne 0 ]; then
  echo '*** Token Handler Kubernetes deployment problem encountered'
  exit 1
fi
