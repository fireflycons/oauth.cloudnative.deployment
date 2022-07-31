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
# Install the MetalLB load balancer
#
echo 'Creating the software load balancer ...'
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/metallb.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered deploying the software load balancer'
  exit 1
fi

#
# Get the KIND IP CIDR and create an IP address ranges that MetalLB will use
# https://medium.com/@charled.breteche/kind-cilium-metallb-and-no-kube-proxy-a9fe66ddfad6
#
KIND_NET_CIDR=$(docker network inspect kind -f '{{(index .IPAM.Config 0).Subnet}}')
METALLB_IP_START=$(echo ${KIND_NET_CIDR} | sed "s@0.0/16@255.1@")
METALLB_IP_END=$(echo ${KIND_NET_CIDR} | sed "s@0.0/16@255.250@")
METALLB_IP_RANGE="${METALLB_IP_START}-${METALLB_IP_END}"

#
# Update the MetalLB configuration
#
echo 'Configuring the load balancer IP address range ...'
export METALLB_IP_RANGE
envsubst < ./base/metallb-config-template.yaml > ./base/metallb-config.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the MetalLB configuration'
  exit 1
fi

#
# Configure MetalLB with IP addresses to distribute to services of type loadbalancer
#
kubectl -n metallb-system delete -f base/metallb-config.yaml 2>/dev/null
kubectl -n metallb-system apply  -f base/metallb-config.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered reconfiguring MetalLB'
  exit 1
fi

#
# Download an Ingress NGINX file adjusted for KIND
#
echo 'Installing the Ingress Controller ...'
DEPLOY_INGRESS_FILE='./base/deploy-ingress-nginx.yaml'
curl -s https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml -o "$DEPLOY_INGRESS_FILE"
if [ $? -ne 0 ]; then
  echo '*** Problem encountered downloading NGINX ingress resources'
  exit 1
fi

#
# Change it to use a service type of load balancer then run the deployment
#
INGRESS_CONFIG=$(cat "$DEPLOY_INGRESS_FILE" | sed s/NodePort/LoadBalancer/g)
echo "$INGRESS_CONFIG" > "$DEPLOY_INGRESS_FILE"
kubectl delete -f "$DEPLOY_INGRESS_FILE" 2>/dev/null
kubectl apply  -f "$DEPLOY_INGRESS_FILE"
if [ $? -ne 0 ]; then
  echo '*** Problem encountered deploying NGINX ingress resources'
  exit 1
fi

#
# Wait for the Ingress resources to create
#
echo 'Waiting for the Ingress Controller to become available ...'
kubectl wait --namespace ingress-nginx \
--for=condition=ready pod \
--selector=app.kubernetes.io/component=controller \
--timeout=300s

#
# Get the external IP used to call into the cluster
#
CLUSTER_IP=$(kubectl get svc/ingress-nginx-controller -n ingress-nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "The cluser's external IP address is $CLUSTER_IP ..."

#
# Create namespaces for application components and third party components
#
echo 'Creating application namespaces ...'
kubectl apply -f base/namespaces.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating Kubernetes namespaces'
  exit 1
fi

#
# Deploy a utility POD for troubleshooting inside the development cluster
# This contains tools such as curl for checking connections
#
echo 'Deploying utility pods ...'
cd utils
kubectl -n deployed apply -f network-multitool.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered deploying troubleshooting tools'
  exit 1
fi
kubectl -n deployed rollout status daemonset/network-multitool
echo 'Base cluster setup completed successfully ...'
