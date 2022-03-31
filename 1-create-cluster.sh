#!/bin/bash

#############################################################################################
# Base setup for a cluster with 2 virtual machines (nodes), after running 'brew install kind'
#############################################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Use Calico by default, but also support Cilium via a command line argument
#
NETWORKING_STACK="$1"
if [ "$NETWORKING_STACK" != 'cilium' ]; then
  NETWORKING_STACK='calico'
fi

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
# Create the namespace
#
kubectl apply -f base/namespace.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the Kubernetes namespace'
  exit 1
fi

#
# Install the Container Networking Interface
#
if [ "$NETWORKING_STACK" == 'calico' ]; then

  #
  # Do the Calico install from the online yaml file
  #
  echo 'Installing Calico networking components ...'
  kubectl apply -f https://projectcalico.docs.tigera.io/manifests/calico.yaml
  if [ $? -ne 0 ]; then
    echo "*** Problem encountered deploying Calico networking"
    exit 1
  fi

  #
  # Turn off reverse path filtering checks, which does not work in the KIND development system
  # https://alexbrand.dev/post/creating-a-kind-cluster-with-calico-networking/
  #
  kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

else

  #
  # Do the Cilium install using the Helm chart
  # https://docs.cilium.io/en/v1.11/gettingstarted/kind/
  #
  echo 'Installing Cilium networking components ...'
  helm repo remove cilium 2>/dev/null
  helm repo add cilium https://helm.cilium.io/

  docker pull cilium/cilium:v1.11.3
  if [ $? -ne 0 ]; then
    echo "*** Problem encountered pulling Cilium Docker image"
    exit 1
  fi

  helm install cilium cilium/cilium --version 1.11.3 \
  --namespace kube-system \
  --set kubeProxyReplacement=partial \
  --set hostServices.enabled=false \
  --set externalIPs.enabled=true \
  --set nodePort.enabled=true \
  --set hostPort.enabled=true \
  --set bpf.masquerade=false \
  --set image.pullPolicy=IfNotPresent \
  --set ipam.mode=kubernetes
  if [ $? -ne 0 ]; then
    echo "*** Problem encountered deploying Cilium networking"
    exit 1
  fi
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
# Show the kube-system nodes and pods
#
kubectl get pods -n kube-system -o wide