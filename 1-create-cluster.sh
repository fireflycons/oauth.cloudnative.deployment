#!/bin/bash

####################################################################
# Base setup for a cluster with 2 nodes hosting the application pods
####################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Switch so that we can get the best setup for each platform
#
case "$(uname -s)" in

  Linux*)
    CLUSTER_FILE_PATH='./base/linux/cluster.yaml'
    INGRESS_SCRIPT_PATH='./base/linux/install-ingress.sh'
	;;

  Darwin)
    CLUSTER_FILE_PATH='./base/mac-windows/cluster.yaml'
    INGRESS_SCRIPT_PATH='./base/mac-windows/install-ingress.sh'
 	;;

  MINGW64*)
    CLUSTER_FILE_PATH='./base/mac-windows/cluster.yaml'
    INGRESS_SCRIPT_PATH='./base/mac-windows/install-ingress.sh'
	;;
esac

#
# Tear down the cluster if it exists already, then create it
#
echo 'Creating the Kubernetes cluster ...'
kind delete cluster --name=oauth 2>/dev/null
kind create cluster --name=oauth --config="$CLUSTER_FILE_PATH"
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Kubernetes cluster'
  exit 1
fi

#
# Install ingress in the best way for the current development platform
#
eval "$INGRESS_SCRIPT_PATH"
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Kubernetes cluster'
  exit 1
fi

#
# Create namespaces for application components and third party components
#
echo 'Creating application namespaces ...'
kubectl apply -f base/namespaces.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating Kubernetes namespaces'
  exit 1
fi

#
# Deploy a utility POD for troubleshooting inside the development cluster
# This contains tools such as curl for checking connections
#
echo 'Deploying utility pods ...'
cd utils
kubectl -n deployed apply -f network-multitool.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered deploying troubleshooting tools'
  exit 1
fi
