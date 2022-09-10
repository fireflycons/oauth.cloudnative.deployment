#!/bin/bash

#########################################################################
# This builds application code into Docker containers ready for deploying
#########################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"
export CLUSTER_TYPE='local'

#
# Default to the Node.js API
#
API_TECH="$1"
if [ "$API_TECH" == 'netcore' ]; then
  API_TECH='netcore'
elif [ "$API_TECH" == 'java' ]; then
  API_TECH='java'
else
  API_TECH='nodejs'
fi

#
# Build Web Host and SPA resources
#
rm -rf finalspa 2>/dev/null
git clone https://github.com/gary-archer/oauth.websample.final finalspa
if [ $? -ne 0 ]; then
  echo '*** Final SPA download problem encountered'
  exit 1
fi

./finalspa/deployment/kubernetes/build.sh
if [ $? -ne 0 ]; then
  echo '*** Final SPA build problem encountered'
  exit 1
fi

#
# Build API resources
#
rm -rf finalapi 2>/dev/null
if [ "$API_TECH" == 'nodejs' ]; then
  
  git clone https://github.com/gary-archer/oauth.apisample.nodejs finalapi
  if [ $? -ne 0 ]; then
    echo '*** Node.js API download problem encountered'
    exit 1
  fi

elif [ "$API_TECH" == 'netcore' ]; then

  git clone https://github.com/gary-archer/oauth.apisample.netcore finalapi
  if [ $? -ne 0 ]; then
    echo '*** .NET API download problem encountered'
    exit 1
  fi

elif [ "$API_TECH" == 'java' ]; then

  git clone https://github.com/gary-archer/oauth.apisample.javaspringboot finalapi
  if [ $? -ne 0 ]; then
    echo '*** Java API download problem encountered'
    exit 1
  fi
fi

./finalapi/deployment/kubernetes-local/build.sh
if [ $? -ne 0 ]; then
  echo '*** Final API build problem encountered'
  exit 1
fi

#
# Build token handler resources
#
rm -rf tokenhandler 2>/dev/null
git clone https://github.com/gary-archer/oauth.tokenhandler.docker tokenhandler
if [ $? -ne 0 ]; then
  echo '*** Token handler download problem encountered'
  exit 1
fi

./tokenhandler/deployment/kubernetes/build.sh
if [ $? -ne 0 ]; then
  echo '*** Token Handler build problem encountered'
  exit 1
fi