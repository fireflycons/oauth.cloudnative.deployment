#!/bin/bash

###########################################################################
# Install the Kubernetes dashboard for visualization of namespaces and pods
###########################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Install the dashboard using the Helm chart
#
echo 'Installing the Kubernetes dashboard ...'
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard 1>/dev/null
helm repo update
helm uninstall kubernetes-dashboard --namespace kubernetes-dashboard 2>/dev/null
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --values ./helm-values.yaml --namespace kubernetes-dashboard --create-namespace
if [ $? -ne 0 ]; then
  echo '*** Problem encountered installing ingress resources'
  exit 1
fi

#
# Wait for the dashboard to come up
#
echo 'Waiting for the Kubernetes dashboard to come up ...'
sleep 5
kubectl wait --namespace kubernetes-dashboard \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=kubernetes-dashboard \
  --timeout=300s

#
# Create a secret for the root CA for ingress external https URLs
#
kubectl -n kubernetes-dashboard delete secret mycluster-com-tls 2>/dev/null
kubectl -n kubernetes-dashboard create secret tls mycluster-com-tls --cert=../../certs/mycluster.ssl.pem --key=../../certs/mycluster.ssl.key
if [ $? -ne 0 ]; then
  echo '*** Problem creating ingress SSL wildcard secret for the kubernetes-dashboard namespace'
  exit 1
fi

#
# Expose the dashboard via an Ingress
#
echo 'Creating an ingress for the Kubernetes dashboard ...'
kubectl -n kubernetes-dashboard delete -f ingress-kong.yaml 2>/dev/null
kubectl -n kubernetes-dashboard apply  -f ingress-kong.yaml

#
# Enable the Skip option to have admin access, for a simple initial development setup
#
echo 'Granting default access to the Kubernetes dashboard ...'
kubectl delete -f adminaccess.yaml 2>/dev/null
kubectl apply  -f adminaccess.yaml

