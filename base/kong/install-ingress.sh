#!/bin/bash

############################################################################################
# Install the Kong ingress controller, which can act as an API gateway that runs LUA plugins
############################################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Build a custom Docker image containing Curity's OAuth Proxy plugin
# https://github.com/curityio/nginx-lua-oauth-proxy-plugin
#
docker build --no-cache -t custom_kong:2.8.1-alpine .
if [ $? -ne 0 ]; then
  echo '*** Problem encountered building the Kong custom Docker image'
  exit 1
fi

#
# Load it into the KIND Docker registry
#
kind load docker-image custom_kong:2.8.1-alpine --name oauth
if [ $? -ne 0 ]; then
  echo '*** Problem encountered deploying the Kong custom Docker image'
  exit 1
fi

#
# Install the Kong open source ingress controller in a stateless setup
#
echo 'Installing ingress resources ...'
helm repo add kong https://charts.konghq.com 1>/dev/null
helm repo update
helm uninstall kong --namespace kong 2>/dev/null
helm install kong kong/kong --values ./helm-values.yaml --namespace kong --create-namespace
if [ $? -ne 0 ]; then
  echo '*** Problem encountered installing ingress resources'
  exit 1
fi

#
# On macOS or Windows, tell KIND that host port 443 should be routed to the ingress controller's container
# This relies on port 443 being included in extraPortMappings in the cluster.yaml file
# https://kind.sigs.k8s.io/docs/user/ingress/
#
if [ "$(uname -s)" != 'linux' ]; then

  echo 'Enabling the host computer to access the Kong ingress ...'
  kubectl patch service    -n kong kong-kong-proxy -p '{"spec":{"type":"NodePort"}}'
  kubectl patch deployment -n kong kong-kong --patch-file ./portmapping-patches.json
  if [ $? -ne 0 ]; then
    echo '*** Problem encountered applying port mappings for the Kong ingress controller'
    exit 1
  fi
fi

#
# Wait for the ingress controller to come up
#
echo 'Waiting for the Kong ingress controller to come up ...'
sleep 5
kubectl wait --namespace kong \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=app \
  --timeout=300s

#
# Report the external IP address
#
CLUSTER_IP=$(kubectl -n kong get svc kong-kong-proxy -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "The cluster's external IP address is $CLUSTER_IP ..."
