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
# Install Cilium as the Container Networking Interface
#
helm repo add cilium https://helm.cilium.io
helm install cilium cilium/cilium --version 1.11.0 -n kube-system \
--set nodeinit.enabled=true \
--set kubeProxyReplacement=partial \
--set hostServices.enabled=false \
--set externalIPs.enabled=true \
--set nodePort.enabled=true \
--set hostPort.enabled=true \
--set bpf.masquerade=false \
--set image.pullPolicy=IfNotPresent \
--set ipam.mode=kubernetes
if [ $? -ne 0 ]; then
  echo '*** Problem encountered installing Cilium networking'
  exit 1
fi

#
# Deploy ingress so that components can be exposed from the cluster over port 443 to the development computer
#
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
if [ $? -ne 0 ]; then
  echo "*** Problem encountered deploying ingress resources"
  exit 1
fi

#
# Wait for ingress to complete installing
#
kubectl wait --namespace ingress-nginx \
--for=condition=ready pod \
--selector=app.kubernetes.io/component=controller \
--timeout=90s

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
