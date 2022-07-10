#!/bin/bash

#############################################
# Build the reverse proxy's custom Dockerfile
#############################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Build the Docker container
#
docker build --no-cache -f Dockerfile -t custom_kong:2.8.1-alpine .
if [ $? -ne 0 ]; then
  echo '*** Reverse proxy docker build problem encountered'
  exit 1
fi

#
# Load it into kind's Docker registry
#
kind load docker-image custom_kong:2.8.1-alpine --name oauth
if [ $? -ne 0 ]; then
  echo '*** Reverse proxy docker deploy problem encountered'
  exit 1
fi
