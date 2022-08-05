#!/bin/bash

###################################################################################################################################
# Install ingress for a macOS or Windows host, where it requires special handling to call into the cluster without port forwarding
# Docker Desktop's network is not exposed to the host computer by default, and the next best option is a patched Ingress controller
###################################################################################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Install the Kong open source ingress controller with no database dependencies
#
echo 'Installing ingress resources ...'
kubectl delete -f https://raw.githubusercontent.com/Kong/kubernetes-ingress-controller/master/deploy/single/all-in-one-dbless.yaml 2>/dev/null
kubectl apply  -f https://raw.githubusercontent.com/Kong/kubernetes-ingress-controller/master/deploy/single/all-in-one-dbless.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered installing ingress resources'
  exit 1
fi

#
# Apply KIND specific patches, so that extraPortMappings allow the host computer to call the Ingress directly
# https://kind.sigs.k8s.io/docs/user/ingress/
#
kubectl patch deployment -n kong ingress-kong --patch-file ../kong-kind-patches.json
if [ $? -ne 0 ]; then
  echo '*** Problem encountered applying KIND specific patches for the ingress controller'
  exit 1
fi

#
# Indicate the 'external' IP address used to call into the cluster
#
echo "The cluster's external IP address is 127.0.0.1 ..."
