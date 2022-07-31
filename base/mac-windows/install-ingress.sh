#!/bin/bash

###################################################################################################################################
# Install ingress for a macOS or Windows host, where it requires special handling to call into the cluster without port forwarding
# Docker Desktop's network is not exposed to the host computer by default, and the next best option is a special Ingress controller
###################################################################################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Install ingress in a way that is patched for KIND, when the cluster configuration includes extra port mappings
# The host computer can then call the ingress directly, though this is a different setup to cloud clusters
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
