#!/bin/bash

####################################################
# Build the Token Handler's code into a Docker image
####################################################

#
# Ensure that we are in the root folder
#
cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..

#
# Get the tokenhandler API
#
rm -rf tokenhandler
git clone https://github.com/gary-archer/oauth.tokenhandlerapi tokenhandler
if [ $? -ne 0 ]; then
  echo '*** Token handler download problem encountered'
  exit 1
fi

#
# Build its code
#
cd tokenhandler
npm install
npm run buildRelease
if [ $? -ne 0 ]; then
  echo '*** Token handler build problem encountered'
  exit 1
fi

#
# Build the Docker container
#
cp ../certs/default.svc.cluster.local.ca.pem ./trusted.ca.pem
docker build --no-cache -f Dockerfile -t tokenhandler:v1 .
if [ $? -ne 0 ]; then
  echo '*** Token Handler docker build problem encountered'
  exit 1
fi

#
# Load it into kind's Docker registry
#
kind load docker-image tokenhandler:v1 --name oauth
if [ $? -ne 0 ]; then
  echo '*** Token handler docker deploy problem encountered'
  exit 1
fi