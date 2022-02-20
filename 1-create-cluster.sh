#!/bin/bash

#############################################################################################
# Base setup for a cluster with 2 virtual machines (nodes), after running 'brew install kind'
#############################################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Tear down the cluster if it exists already, then create it
#
echo 'Creating the Kubernetes cluster ...'
kind delete cluster --name=oauth
kind create cluster --name=oauth --config=base/cluster.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Kubernetes cluster'
  exit 1
fi

#
# Create the namespace
#
kubectl apply -f base/namespace.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Kubernetes namespace'
  exit 1
fi

#
# Install Calico as the Container Networking Interface
#e
echo 'Installing networking components ...'
kubectl apply -f https://projectcalico.docs.tigera.io/manifests/calico.yaml
if [ $? -ne 0 ]; then
  echo "*** Problem encountered deploying Calico networking"
  exit 1
fi

#
# Deploy ingress so that components can be exposed from the cluster over port 443 to the development computer
#
echo 'Installing ingress components ...'
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
if [ $? -ne 0 ]; then
  echo "*** Problem encountered deploying ingress resources"
  exit 1
fi

#
# Wait for the network setup to complete, which involves some large downloads
#
echo 'Waiting up to 15 minutes for networking setup to complete ...'
kubectl wait --namespace ingress-nginx \
--for=condition=ready pod \
--selector=app.kubernetes.io/component=controller \
--timeout=900s

#
# Deploy a utility POD for troubleshooting
#
cd utils
kubectl -n deployed apply -f network-multitool.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered deploying troubleshooting tools'
  exit 1
fi

#
# Wait for the pod to reach a ready state
#
kubectl -n deployed rollout status daemonset/network-multitool

#
# Indicate success
#
echo 'Cluster was created successfully'
