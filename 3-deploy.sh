#!/bin/bash

###############################################################################
# This deploys Docker containers needed to run apps into the Kubernetes cluster 
###############################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"
export CLUSTER_TYPE='local'

#
# First create the namespace
#
kubectl delete namespace applications 2>/dev/null
kubectl create namespace applications
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the applications namespace'
  exit 1
fi

#
# Create a secret for the root CA for cluster internal https URLs
#
kubectl -n applications delete secret default-svc-cluster-local 2>/dev/null
kubectl -n applications create secret tls default-svc-cluster-local --cert=./certs/default.svc.cluster.local.ca.pem --key=./certs/default.svc.cluster.local.ca.key
if [ $? -ne 0 ]; then
  echo '*** Problem creating deploying a secret for internal SSL Root Authority to the applications namespace ***'
  exit 1
fi

#
# Create the cluster issuer for this namespace
#
kubectl -n applications apply -f ./base/certmanager/clusterIssuer.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem deploying the cluster issuer to the applications namespace'
  exit 1
fi

#
# Deploy web host and SPA resources
#
./finalspa/deployment/kubernetes/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Deploy the API
#
./finalapi/deployment/kubernetes/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Deploy token handler components
#
./tokenhandler/deployment/kubernetes/deploy.sh
if [ $? -ne 0 ]; then
  exit 1
fi
