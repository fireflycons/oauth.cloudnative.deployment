#!/bin/bash

#########################################################################
# This deploys Elastic Stack Docker resources into the Kubernetes cluster
########################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Get Elastic Stack resources
#
rm -rf elasticstack
git clone https://github.com/gary-archer/logaggregation.elasticsearch elasticstack
if [ $? -ne 0 ]; then
  echo '*** Elastic Stack download problem encountered'
  exit 1
fi

# TODO: delete after merging
cd elasticstack
git checkout feature/kong
cd ..

#
# Run the deployment of Elastic Stack components
#
./elasticstack/deployment/kubernetes-local/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi
