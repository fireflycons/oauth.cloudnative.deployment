#!/bin/bash

###############################################################################
# This deploys Docker containers needed to run apps into the Kubernetes cluster 
###############################################################################

API_TECH='nodejs'

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

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
# Deploy the token handler
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

#
# Indicate success
#
echo 'All application resources were deployed successfully'
