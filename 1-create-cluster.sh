#!/bin/bash

####################################################################
# Base setup for a cluster with 2 nodes hosting the application pods
####################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"


#
# Tear down the cluster if it exists already, then create it, along with namespaces
#
echo 'Creating the Kubernetes cluster ...'
kind delete cluster --name=oauth 2>/dev/null
if [ "$(uname -s)" == 'linux' ]; then
  kind create cluster --name=oauth --config='./base/cluster/cluster-loadbalancer.yaml'
else
  kind create cluster --name=oauth --config='./base/cluster/cluster-extraportmappings.yaml'
fi
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Kubernetes cluster'
  exit 1
fi

#
# On Linux, deploy a load balancer, to enable external IP addresses
#
if [ "$(uname -s)" == 'linux' ]; then

  ./base/loadbalancer/install-loadbalancer.sh
  if [ $? -ne 0 ]; then
    exit 1
  fi
fi

#
# Install the Kong ingress controller
#
./base/kong/install-ingress.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Set up certificate related resources
#
./base/certmanager/install-certs.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Install and expose the Kubernetes dashboard
#
./base/dashboard/install-dashboard.sh
if [ $? -ne 0 ]; then
  exit 1
fi
