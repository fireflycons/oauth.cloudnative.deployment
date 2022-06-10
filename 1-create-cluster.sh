#!/bin/bash

####################################################################
# Base setup for a cluster with 2 nodes hosting the application pods
####################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Tear down the cluster if it exists already, then create it
#
echo 'Creating the Kubernetes cluster ...'
kind delete cluster --name=oauth 2>/dev/null
kind create cluster --name=oauth --config=base/cluster.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Kubernetes cluster'
  exit 1
fi

#
# Create the namespace for application components
#
kubectl apply -f base/application-namespace.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Kubernetes namespace'
  exit 1
fi

#
# Install Calico for advanced networking capabilities
# This works on development computers across the 3 platforms
# curl -k -O https://projectcalico.docs.tigera.io/manifests/calico.yaml
# 
# KIND's default for the pod CIDR is 10.244.0.0/16, and Calico's default is 192.168.0.0/16
# This file has been edited so that Calico uses CALICO_IPV4POOL_CIDR=10.244.0.0/16
# This prevents outbound DNS problems later, especially on Windows
# https://github.com/projectcalico/calico/issues/2962#issuecomment-547979845
#
kubectl apply -f base/calico.yaml
if [ $? -ne 0 ]; then
  echo "*** Problem encountered deploying Calico networking"
  exit 1
fi

#
# Turn off reverse path filtering checks, which does not work in the KIND development system
# https://alexbrand.dev/post/creating-a-kind-cluster-with-calico-networking/
#
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

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
# Show the kube-system nodes and pods
#
kubectl get pods -n kube-system -o wide
