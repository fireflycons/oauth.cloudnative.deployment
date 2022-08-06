#!/bin/bash

###############################################################################################
# Does the shared setup for the customized Kong ingress controller, which runs security plugins
###############################################################################################

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
