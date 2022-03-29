#!/bin/bash

#####################################################################
# Create resources needed for SSL both inside and outside the cluster
#####################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# First download certificates for mycompany.com from the shared repo
#
rm -rf resources
git clone https://github.com/gary-archer/oauth.developmentcertificates resources
if [ $? -ne 0 ]; then
  exit 1
fi
rm -rf certs
mv ./resources/mycompany ./certs
rm -rf ./resources

#
# Create a secret for external URLs
#
cd certs
kubectl -n deployed delete secret mycompany-com-tls 2>/dev/null
kubectl -n deployed create secret tls mycompany-com-tls --cert=./mycompany.ssl.pem --key=./mycompany.ssl.key
if [ $? -ne 0 ]; then
  echo '*** Problem creating ingress SSL wildcard secret'
  exit 1
fi

#
# Next deploy certificate manager, used to issue certificates to applications inside the cluster
#
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml

#
# Wait for cert manager to initialize as described here, so that our root cluster certificate is trusted
# https://github.com/jetstack/cert-manager/issues/3338#issuecomment-707579834
#
echo 'Waiting for cainjector to inject CA certificates into web hook ...'
sleep 45

#
# Point to the OpenSSL configuration file for the platform
#
case "$(uname -s)" in

  # Mac OS
  Darwin)
    export OPENSSL_CONF='/System/Library/OpenSSL/openssl.cnf'
 	;;

  # Windows with Git Bash
  MINGW64*)
    export OPENSSL_CONF='C:/Program Files/Git/usr/ssl/openssl.cnf';
    export MSYS_NO_PATHCONV=1;
	;;
esac

#
# Root certificate details for inside the cluster
#
ROOT_CERT_FILE_PREFIX='default.svc.cluster.local.ca'
ROOT_CERT_DESCRIPTION='Self Signed CA for svc.default.cluster'

#
# Create the root certificate private key
#
openssl genrsa -out $ROOT_CERT_FILE_PREFIX.key 2048
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the internal Root CA key'
  exit 1
fi

#
# Create the public key root certificate file, which has a long lifetime
#
openssl req -x509 \
    -new \
    -nodes \
    -key $ROOT_CERT_FILE_PREFIX.key \
    -out $ROOT_CERT_FILE_PREFIX.pem \
    -subj "/CN=$ROOT_CERT_DESCRIPTION" \
    -reqexts v3_req \
    -extensions v3_ca \
    -sha256 \
    -days 3650
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the internal Root CA'
  exit 1
fi

#
# Deploy a secret for the internal root CA, used by the cluster issuer
#
kubectl -n deployed delete secret default-svc-cluster-local 2>/dev/null
kubectl -n deployed create secret tls default-svc-cluster-local --cert=./default.svc.cluster.local.ca.pem --key=./default.svc.cluster.local.ca.key
if [ $? -ne 0 ]; then
  echo '*** Problem creating secret for internal SSL Root Authority ***'
  exit 1
fi

#
# Create the cluster issuer
#
cd ../base
kubectl -n deployed apply -f ./clusterIssuer.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem creating the cluster issuer'
  exit 1
fi

#
# Show the cert-manager nodes and pods
#
kubectl get pods -n cert-manager -o wide
