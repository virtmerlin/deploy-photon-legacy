#!/bin/bash +x
set -e

# Get Photon CLI
echo "Downloading Photon CLI..."
if [[ $cli_url == "latest" || -z "$cli_url" ]]; then
  echo "Using default url."
  cli_url=$(wget -q -O- https://github.com/vmware/photon-controller/wiki/download | grep "linux cli tools" | egrep -o http.*\" | tr -d "\"")
fi
wget $cli_url -O /sbin/photon
chmod 755 /sbin/photon
