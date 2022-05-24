#!/bin/bash

########################################################################
# This builds application ode into Docker containers ready for deploying
########################################################################

API_TECH='nodejs'

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Build SPA resources
#
./finalspa-scripts/build.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Build the API
#
./finalapi-scripts/build.sh "$API_TECH"
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Build the reverse proxy
#
./reverseproxy/build.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Build the OAuth Agent
#
./oauth-agent-scripts/build.sh
if [ $? -ne 0 ]; then
  exit 1
fi
