#!/bin/bash

#########################################################################
# This deploys Elastic Stack Docker resources into the Kubernetes cluster
########################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# First create the namespace
#
kubectl delete namespace elasticstack
kubectl create namespace elasticstack
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the elasticstack namespace'
  exit 1
fi

#
# Create a secret for the root CA for ingress external https URLs
#
kubectl -n elasticstack delete secret mycluster-com-tls 2>/dev/null
kubectl -n elasticstack create secret tls mycluster-com-tls --cert=./certs/mycluster.ssl.pem --key=./certs/mycluster.ssl.key
if [ $? -ne 0 ]; then
  echo '*** Problem creating ingress SSL wildcard secret for the elasticstack namespace'
  exit 1
fi

#
# Create a secret for the root CA for cluster internal https URLs
#
kubectl -n elasticstack delete secret default-svc-cluster-local 2>/dev/null
kubectl -n elasticstack create secret tls default-svc-cluster-local --cert=./certs/default.svc.cluster.local.ca.pem --key=./certs/default.svc.cluster.local.ca.key
if [ $? -ne 0 ]; then
  echo '*** Problem deploying a secret for the internal SSL Root Authority to the elasticstack namespace ***'
  exit 1
fi

#
# Create the cluster issuer for this namespace
#
kubectl -n elasticstack apply -f ./base/certmanager/clusterIssuer.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem creating the cluster issuer to the elasticstack namespace'
  exit 1
fi

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
# Run the deployment of Elastic Stack components
#
./elasticstack/deployment/kubernetes-local/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi
