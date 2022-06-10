#!/bin/bash

###############################################################################
# This deploys Docker containers needed to run apps into the Kubernetes cluster 
###############################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Default to the Node.js API
#
API_TECH='$1'
if [ "$API_TECH" == 'netcore' ]; then
  API_TECH='netcore'
elif [ "$API_TECH" == 'java' ]; then
  API_TECH='java'
else
  API_TECH='nodejs'
fi

#
# Deploy SPA resources
#
./finalspa-scripts/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Deploy the API
#
./finalapi-scripts/deploy.sh "$API_TECH"
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Deploy the OAuth Agent
#
./oauth-agent-scripts/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Deploy the reverse proxy
#
./reverseproxy/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi
