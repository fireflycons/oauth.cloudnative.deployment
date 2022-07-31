#!/bin/bash

#####################################################################
# Create resources needed for SSL both inside and outside the cluster
#####################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Point to the OpenSSL configuration file for the platform
#
case "$(uname -s)" in

  Darwin)
    export OPENSSL_CONF='/System/Library/OpenSSL/openssl.cnf'
 	;;

  MINGW64*)
    export OPENSSL_CONF='C:/Program Files/Git/usr/ssl/openssl.cnf';
    export MSYS_NO_PATHCONV=1;
	;;

  Linux*)
    export OPENSSL_CONF='/usr/lib/ssl/openssl.cnf';
	;;
esac

#
# First download certificates for mycluster.com from the shared repo
#
rm -rf resources
git clone https://github.com/gary-archer/oauth.developmentcertificates resources
if [ $? -ne 0 ]; then
  exit 1
fi
rm -rf certs
mv ./resources/mycluster ./certs
rm -rf ./resources

#
# Create secrets for external URLs
#
cd certs
kubectl -n deployed delete secret mycluster-com-tls 2>/dev/null
kubectl -n deployed create secret tls mycluster-com-tls --cert=./mycluster.ssl.pem --key=./mycluster.ssl.key
if [ $? -ne 0 ]; then
  echo '*** Problem creating ingress SSL wildcard secret for the deployed namespace'
  exit 1
fi

kubectl -n elasticstack delete secret mycluster-com-tls 2>/dev/null
kubectl -n elasticstack create secret tls mycluster-com-tls --cert=./mycluster.ssl.pem --key=./mycluster.ssl.key
if [ $? -ne 0 ]; then
  echo '*** Problem creating ingress SSL wildcard secret for the elasticstack namespace'
  exit 1
fi

#
# Next deploy certificate manager, used to issue certificates to applications inside the cluster
#
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.8.0/cert-manager.yaml

#
# Wait for cert manager to initialize as described here, so that our root cluster certificate is trusted
# https://github.com/jetstack/cert-manager/issues/3338#issuecomment-707579834
#
echo 'Waiting for cainjector to inject CA certificates into web hook ...'
sleep 45

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
  echo '*** Problem creating deploying a secret for internal SSL Root Authority to the deployed namespace ***'
  exit 1
fi

kubectl -n elasticstack delete secret default-svc-cluster-local 2>/dev/null
kubectl -n elasticstack create secret tls default-svc-cluster-local --cert=./default.svc.cluster.local.ca.pem --key=./default.svc.cluster.local.ca.key
if [ $? -ne 0 ]; then
  echo '*** Problem deploying a secret for the internal SSL Root Authority to the elasticstack namespace ***'
  exit 1
fi

#
# Create the cluster issuer
#
cd ../base
kubectl -n deployed apply -f ./clusterIssuer.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem deploying the cluster issuer to the deployed namespace'
  exit 1
fi

kubectl -n elasticstack apply -f ./clusterIssuer.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem creating the cluster issuer to the elasticstack namespace'
  exit 1
fi
