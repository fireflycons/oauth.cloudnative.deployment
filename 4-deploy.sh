#!/bin/bash

###############################################################################
# This deploys Docker containers needed to run apps into the Kubernetes cluster 
###############################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Deploy SPA resources
#
./finalspa/deployment/kubernetes-local/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Deploy the API
#
./finalapi/deployment/kubernetes-local/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Deploy token handler components
#
./tokenhandler/deployment/kubernetes-local/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi
