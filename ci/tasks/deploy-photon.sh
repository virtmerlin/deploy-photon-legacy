#!/bin/bash
set -e

# Download Photon CLI
my_dir="$(dirname "$0")"
"$my_dir/download-cli.sh"

photon target set http://${ova_ip}:9000

#Destory Existing Deployments
if (( $(photon -n deployment list | wc -l) > 0 )); then
    photon system destroy
fi

#Deploy Photon Controller
photon system deploy deploy-photon/manifests/photon/$photon_manifest 2>&1
echo "sleep 3 minutes while photon ctrlrs are starting"
sleep 180

#Target Photon Controller
PHOTON_CTRL_ID=$(photon deployment list | head -3 | tail -1)
PHOTON_CTRL_IP=$(photon deployment show $PHOTON_CTRL_ID | grep -E "LoadBalancer.*28080" | awk -F " " '{print$2}')
AUTH_ENABLED=$(photon -n deployment show $PHOTON_CTRL_ID | sed -n 2p | awk '{print $1;}')
if [ $AUTH_ENABLED == "false" ]; then
    photon target set http://${PHOTON_CTRL_IP}:9000
else
    photon -n target set -c https://${PHOTON_CTRL_IP}:443
    photon -n target login -u "$photon_user" -p "$photon_passwd"
fi

##Create Tenant
photon -n tenant create $photon_tenant
photon -n tenant set $photon_tenant

##Create Project & Link Resources
photon -n resource-ticket create --name $photon_project-ticket --limits "vm.memory 3600 GB, vm 10000 COUNT" -t $photon_tenant
echo 'y' | photon project create --name $photon_project --limits "vm.memory 3600 GB, vm 10000 COUNT" -r $photon_project-ticket
photon -n project set $photon_project


#Show Project ID
photon project list

## Create Photon Flavors for PCF
# 000's - ultra small VMs
# 1 cpu, 8MB memory
photon -n flavor create -n core-10 -k vm -c "vm.cpu 1 COUNT,vm.memory 32 MB"
# 100's - entry level, non-production sla only
# 1 cpu, 2GB memory, vm.cost = 1.0 baseline
photon -n flavor create -n core-100 -k vm -c "vm.cpu 1 COUNT,vm.memory 2 GB"
# 1 cpu, 4GB memory, vm.cost = 1.5 baseline
# intention is ~parity with GCE n1-standard-1 (ephemeral root)
photon -n flavor create -n core-110 -k vm -c "vm.cpu 1 COUNT,vm.memory 4 GB"
# 200's - entry level production class vm's in an HA environment
# 2 cpu, 4GB memory, vm.cost 2.0
photon -n flavor create -n core-200 -k vm -c "vm.cpu 2 COUNT,vm.memory 4 GB"
# 2 cpu, 8GB memory, vm.cost 4.0
# intention is ~parity with GCE n1-standard-2 (ephemeral root)
photon -n flavor create -n core-220 -k vm -c "vm.cpu 2 COUNT,vm.memory 8 GB"
# 4 cpu, 16GB memory, vm.cost 12.0
# intention is ~parity with GCE n1-standard-4 (ephemeral root)
photon -n flavor create -n core-240 -k vm -c "vm.cpu 2 COUNT,vm.memory 16 GB"
# 4 cpu, 32GB memory, vm.cost 20.0
photon -n flavor create -n core-245 -k vm -c "vm.cpu 2 COUNT,vm.memory 32 GB"
# 8 cpu, 32GB memory, vm.cost 25.0
# intention is ~parity with GCE n1-standard-8 (ephemeral root)
photon -n flavor create -n core-280 -k vm -c "vm.cpu 8 COUNT,vm.memory 32 GB"
# 8 cpu, 64GB memory, vm.cost 48.0
# intention is ~parity with GCE n1-standard-8 (ephemeral root)
photon -n flavor create -n core-285 -k vm -c "vm.cpu 8 COUNT,vm.memory 64 GB"
# flavor used for failure test
photon -n flavor create -n huge-vm -k vm -c "vm.cpu 8000 COUNT,vm.memory 9000 GB"
## disks
# comment out unused flavor
#photon -n flavor create -n pcf-2 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 2 GB"
#photon -n flavor create -n pcf-4 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 4 GB"
#photon -n flavor create -n pcf-20 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 20 GB"
#photon -n flavor create -n pcf-100 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 100 GB"
#photon -n flavor create -n pcf-16 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 16 GB"
#photon -n flavor create -n pcf-32 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 32 GB"
#photon -n flavor create -n pcf-64 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 64 GB"
#photon -n flavor create -n pcf-128 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 128 GB"
#photon -n flavor create -n pcf-256 -k ephemeral-disk -c "ephemeral-disk 1 COUNT,ephemeral-disk.capacity 256 GB"
photon -n flavor create -n core-100 -k ephemeral-disk -c "ephemeral-disk 1 COUNT"
photon -n flavor create -n core-200 -k ephemeral-disk -c "ephemeral-disk 1 COUNT"
photon -n flavor create -n core-300 -k ephemeral-disk -c "ephemeral-disk 1 COUNT"
photon -n flavor create -n core-100 -k persistent-disk -c "persistent-disk 1 COUNT"
photon -n flavor create -n core-200 -k persistent-disk -c "persistent-disk 1 COUNT"
photon -n flavor create -n core-300 -k persistent-disk -c "persistent-disk 1 COUNT"
