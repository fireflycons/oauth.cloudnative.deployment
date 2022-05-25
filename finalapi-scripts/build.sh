#!/bin/bash

##########################################
# Build the API's code into a Docker image
##########################################

#
# Ensure that we are in the root folder
#
cd "$(dirname "${BASH_SOURCE[0]}")"
cd ..

#
# Check for a valid command line parameter
#
API_TECH="$1"
if [ "$API_TECH" != 'nodejs' ] && [ "$API_TECH" != 'netcore' ] && [ "$API_TECH" != 'java' ]; then
  echo '*** An invalid API_TECH parameter was supplied'
  exit 1
fi

#
# Ensure that we start clean
#
rm -rf finalapi

#
# Build the Node.js API
#
if [ "$API_TECH" == 'nodejs' ]; then
  
  git clone https://github.com/gary-archer/oauth.apisample.nodejs finalapi
  if [ $? -ne 0 ]; then
    echo '*** Node API download problem encountered'
    exit 1
  fi
  
  cd finalapi
  npm install
  npm run buildRelease
  if [ $? -ne 0 ]; then
    echo '*** Node API build problem encountered'
    exit 1
  fi
fi

#
# Build the .NET API
#
if [ "$API_TECH" == 'netcore' ]; then

  git clone https://github.com/gary-archer/oauth.apisample.netcore finalapi
  if [ $? -ne 0 ]; then
    echo '*** .NET API download problem encountered'
    exit 1
  fi

  cd finalapi
  dotnet publish sampleapi.csproj -c Release -r linux-x64 --no-self-contained
  if [ $? -ne 0 ]; then
    echo '*** .NET API build problem encountered'
    exit 1
  fi
fi

#
# Build the Java API
#
if [ "$API_TECH" == 'java' ]; then

  git clone https://github.com/gary-archer/oauth.apisample.javaspringboot finalapi
  if [ $? -ne 0 ]; then
    echo '*** Java API download problem encountered'
    exit 1
  fi

  cd finalapi
  ./gradlew bootJar
  if [ $? -ne 0 ]; then
    echo '*** Java API build problem encountered'
    exit 1
  fi
fi

#
# Build the Docker container
#
docker build --no-cache -f docker/Dockerfile -t finalapi:v1 .
if [ $? -ne 0 ]; then
  echo '*** API docker build problem encountered'
  exit 1
fi

#
# Load it into kind's Docker registry
#
kind load docker-image finalapi:v1 --name oauth
if [ $? -ne 0 ]; then
  echo '*** API docker deploy problem encountered'
  exit 1
fi