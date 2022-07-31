#!/bin/bash

#################################################################################################################
# Install ingress for a macOS or Windows environment, where it requires special handling to call into the cluster
# This is because the KIND network is not exposed to the host computer by default
#################################################################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Install ingress in a way that is patched for KIND, which allows the host computer to connect directly to the ingress
# https://kind.sigs.k8s.io/docs/user/ingress/
#
echo 'Installing the Ingress Controller ...'
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml 2>/dev/null
kubectl apply  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered installing NGINX ingress resources'
  exit 1
fi

#
# Wait for the Ingress resources to be created
#
echo 'Waiting for the Ingress Controller to become available ...'
kubectl wait --namespace ingress-nginx \
--for=condition=ready pod \
--selector=app.kubernetes.io/component=controller \
--timeout=300s

#
# Indicate the 'external' IP address used to call into the cluster
#
echo "The cluster's external IP address is 127.0.0.1 ..."