#!/bin/bash

###########################################################
# This deletes the entire cluster and any related resources
###########################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Delete the cluster
#
kind delete cluster --name=oauth
