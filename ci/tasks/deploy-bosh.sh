#!/bin/bash
set -e

# Download Photon CLI
my_dir="$(dirname "$0")"
"$my_dir/download-cli.sh"

#### Build the Photon CPI and get sha1
echo "Building Photon CPI ..."
if [[ $photon_release == "latest" || -z $photon_release ]]; then
        CPI_FILE=$(ls bosh-photon-cpi-release/releases/bosh-photon-cpi/bosh-photon-cpi-*.yml | sort | head -1)
else
        CPI_FILE=$(ls bosh-photon-cpi-release/releases/bosh-photon-cpi/bosh-photon-cpi-$photon_release.yml | sort | head -1)
fi
cd bosh-photon-cpi-release
CPI_RELEASE=$(bosh create release ../$CPI_FILE | grep Generated | awk -F " " '{print$2}')
cd ..
CPI_SHA1=$(openssl sha1 $CPI_RELEASE | awk -F "= " '{print$2}')

#### Get Photon Project Target
echo "Creating Photon Constructs for BOSH Deployment ..."
photon target set http://${ova_ip}:9000
PHOTON_CTRL_ID=$(photon deployment list | head -3 | tail -1)
PHOTON_CTRL_IP=$(photon deployment show $PHOTON_CTRL_ID | grep -E "LoadBalancer.*28080" | awk -F " " '{print$2}')
AUTH_ENABLED=$(photon -n deployment show $PHOTON_CTRL_ID | sed -n 2p | awk '{print $1;}')
if [ $AUTH_ENABLED == "false" ]; then
    PHOTON_CTRL_TARGET=http://${PHOTON_CTRL_IP}:9000
    photon target set $PHOTON_CTRL_TARGET
else
    PHOTON_CTRL_TARGET=https://${PHOTON_CTRL_IP}:443
    photon -n target set -c $PHOTON_CTRL_TARGET
    photon -n target login -u "$photon_user" -p "$photon_passwd"
fi
photon tenant set $photon_tenant
photon project set $photon_project
PHOTON_PROJ_ID=$(photon project list | grep $photon_project |  awk -F " " '{print$1}')

#### Create Photon Network
bosh_deployment_network=$(echo ${bosh_deployment_network} | tr "_" "-")
photon network create -n $bosh_deployment_network_name -p "$bosh_deployment_network" -d "BOSH Deployment Network" || echo "Photon Network $bosh_deployment_network Already Exists ..."
BOSH_DEPLOYMENT_NETWORK_ID=$(photon network list | grep "$bosh_deployment_network" | awk -F " " '{print$1}')
#photon -n network set-default $BOSH_DEPLOYMENT_NETWORK_ID

#### Edit Bosh Manifest & Deploy BOSH
echo "Updating BOSH Manifest template deploy-photon/manifests/bosh/$bosh_manifest ..."
if [ ! -f deploy-photon/manifests/bosh/$bosh_manifest ]; then
    echo "Error: Bosh Manifest not found in deploy-photon/manifests/bosh/ !!!  I got this value for \$bosh_manifest="$bosh_manifest
    exit 1
fi

# Set Photon Specific Deployment Object IDs in BOSH Manifest
cp deploy-photon/manifests/bosh/$bosh_manifest /tmp/bosh.yml

CPI_RELEASE_REGEX=$(echo $CPI_RELEASE | sed 's|/|\\\/|g')
BOSH_DEPLOYMENT_NETWORK_SUBNET_REGEX=$(echo $bosh_deployment_network_subnet | sed 's|/|\\\/|g' | sed 's|\.|\\\.|g')

perl -pi -e "s/PHOTON_PROJ_ID/$PHOTON_PROJ_ID/g" /tmp/bosh.yml
perl -pi -e "s|PHOTON_CTRL_TARGET|$PHOTON_CTRL_TARGET|g" /tmp/bosh.yml
perl -pi -e 's/PHOTON_USER/$ENV{photon_user}/g' /tmp/bosh.yml
perl -pi -e 's/PHOTON_PASSWD/$ENV{photon_passwd}/g' /tmp/bosh.yml
perl -pi -e "s/PHOTON_IGNORE_CERT/$photon_ignore_cert/g" /tmp/bosh.yml
perl -pi -e "s/PHOTON_TENANT/$photon_tenant/g" /tmp/bosh.yml
perl -pi -e "s/CPI_SHA1/$CPI_SHA1/g" /tmp/bosh.yml
perl -pi -e "s/CPI_RELEASE/$CPI_RELEASE_REGEX/g" /tmp/bosh.yml
perl -pi -e "s/BOSH_DEPLOYMENT_NETWORK_ID/$BOSH_DEPLOYMENT_NETWORK_ID/g" /tmp/bosh.yml
perl -pi -e "s/BOSH_DEPLOYMENT_NETWORK_SUBNET/$BOSH_DEPLOYMENT_NETWORK_SUBNET_REGEX/g" /tmp/bosh.yml
perl -pi -e "s/BOSH_DEPLOYMENT_NETWORK_GW/$bosh_deployment_network_gw/g" /tmp/bosh.yml
perl -pi -e "s/BOSH_DEPLOYMENT_NETWORK_DNS/$bosh_deployment_network_dns/g" /tmp/bosh.yml
perl -pi -e "s/BOSH_DEPLOYMENT_NETWORK_IP/$bosh_deployment_network_ip/g" /tmp/bosh.yml
perl -pi -e "s/BOSH_DEPLOYMENT_USER/$bosh_deployment_user/g" /tmp/bosh.yml
perl -pi -e "s/BOSH_DEPLOYMENT_PASSWD/$bosh_deployment_passwd/g" /tmp/bosh.yml

# Deploy BOSH
echo "Deploying BOSH ..."
bosh-init deploy /tmp/bosh.yml

# Target Bosh and test Status Reply
echo "sleep 3 minutes while BOSH starts..."
sleep 180
#BOSH_TARGET=$(cat /tmp/bosh.yml | shyaml get-values jobs.0.networks.0.static_ips)
#BOSH_LOGIN=$(cat /tmp/bosh.yml | shyaml get-value jobs.0.properties.director.user_management.local.users.0.name)
#BOSH_PASSWD=$(cat /tmp/bosh.yml | shyaml get-value jobs.0.properties.director.user_management.local.users.0.password)
bosh -n target https://${bosh_deployment_network_ip}
bosh -n login ${bosh_deployment_user} ${bosh_deployment_passwd}
bosh status
