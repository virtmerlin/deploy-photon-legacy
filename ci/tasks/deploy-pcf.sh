#!/bin/bash
set -e

if [ ! -f deploy-photon/manifests/pcf/${pcf_manifest} ]; then
  echo "ERROR, Can't find ERT Manifest ${pcf_manifest}"
  exit 1
fi

# Download Photon Installer cli
my_dir="$(dirname "$0")"
"$my_dir/download-cli.sh"

bosh -n target https://${bosh_deployment_network_ip}
bosh -n login ${bosh_deployment_user} ${bosh_deployment_passwd}

cp deploy-photon/manifests/pcf/${pcf_manifest} /tmp/${pcf_manifest}

# Get Photon Network ID
photon target set http://${ova_ip}:9000
PHOTON_CTRL_ID=$(photon deployment list | head -3 | tail -1)
PHOTON_CTRL_IP=$(photon deployment show $PHOTON_CTRL_ID | grep -E "LoadBalancer.*28080" | awk -F " " '{print$2}')
AUTH_ENABLED=$(photon -n deployment show $PHOTON_CTRL_ID | sed -n 2p | awk '{print $1;}')
if [ $AUTH_ENABLED == "false" ]; then
    photon target set http://${PHOTON_CTRL_IP}:9000
else
    photon -n target set -c https://${PHOTON_CTRL_IP}:443
    photon -n target login -u "$photon_user" -p "$photon_passwd"
fi
BOSH_DEPLOYMENT_NETWORK_ID=$(photon network list | grep "$bosh_deployment_network" | awk -F " " '{print$1}')

perl -pi -e "s/ignore/`bosh status --uuid`/g" /tmp/${pcf_manifest}
perl -pi -e "s/replace_network_id/$BOSH_DEPLOYMENT_NETWORK_ID/g" /tmp/${pcf_manifest}

bosh deployment /tmp/${pcf_manifest}
bosh -n deploy
