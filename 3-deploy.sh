#!/bin/bash

###############################################################################
# This deploys Docker containers needed to run apps into the Kubernetes cluster 
###############################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

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
# Create a secret for the root CA for ingress external https URLs
#
kubectl -n applications delete secret mycluster-com-tls 2>/dev/null
kubectl -n applications create secret tls mycluster-com-tls --cert=./certs/mycluster.ssl.pem --key=./certs/mycluster.ssl.key
if [ $? -ne 0 ]; then
  echo '*** Problem creating ingress SSL wildcard secret for the applications namespace'
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
