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

#
# Create a secret to deploy the root certificate that filebeat must trust in order to call Elasticsearch over SSL
#
kubectl -n elasticstack delete secret filebeat-root-cert 2>/dev/null
kubectl -n elasticstack create secret generic filebeat-root-cert --from-file=./certs/default.svc.cluster.local.ca.pem
if [ $? -ne 0 ]; then
  echo '*** Problem creating Filebeat SSL root CA secret'
  exit 1
fi

#
# Run the deployment
#
./elasticstack/deployment/kubernetes-local/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi
