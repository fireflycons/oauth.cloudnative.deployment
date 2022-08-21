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
# Next deploy certificate manager, used to issue certificates to applications inside the cluster
#
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.8.0/cert-manager.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered deploying certmanager'
  exit 1
fi

#
# Wait for cert manager to initialize as described here, so that our root cluster certificate is trusted
# https://github.com/jetstack/cert-manager/issues/3338#issuecomment-707579834
#
echo 'Waiting for cainjector to inject CA certificates into web hook ...'
sleep 60

#
# Download ingress certificates for mycluster.com from the shared repo
#
cd ../..
rm -rf resources
git clone https://github.com/gary-archer/oauth.developmentcertificates resources
if [ $? -ne 0 ]; then
  exit 1
fi
rm -rf certs
mv ./resources/mycluster ./certs
rm -rf ./resources

#
# Set root certificate details for internal SSL
#
ROOT_CERT_FILE_PREFIX='default.svc.cluster.local.ca'
ROOT_CERT_DESCRIPTION='Self Signed CA for svc.default.cluster'

#
# Create the root certificate private key
#
cd certs
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
