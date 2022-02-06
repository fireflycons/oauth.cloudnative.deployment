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
# Build the token handler
#
./tokenhandler-scripts/build.sh
if [ $? -ne 0 ]; then
  exit 1
fi

#
# Download the OAuth proxy plugin to run in the reverse proxy
#
rm -rf oauth-proxy-plugin
git clone https://github.com/curityio/nginx-lua-oauth-proxy-plugin oauth-proxy-plugin
if [ $? -ne 0 ]; then
  echo '*** OAuth proxy plugin download problem encountered'
  exit 1
fi
cd oauth-proxy-plugin/plugin
mv plugin.lua access.lua

#
# Indicate success
#
echo 'All application resources were built successfully'
