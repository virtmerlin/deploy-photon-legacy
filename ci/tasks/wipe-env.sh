#!/bin/bash
#set -e

# Function to parse one ip or one ip range
function parseIP() {
	IFS='-' read -r -a RANGESPLIT <<< "$1"
	SIZE=${#RANGESPLIT[@]}
	if (( ${SIZE} > 2 || ${SIZE} < 1 )); then
	    echo "null"
        exit 1
	fi
	prips ${RANGESPLIT[0]} ${RANGESPLIT[${SIZE}-1]} 2>/dev/null || echo "null"
}

# Function to parse address_ranges of each host block
function parseHostBlockIP() {
    declare -a HOSTS=()
    VAL=(hosts.$1.address_ranges)
    TEMPVAL=$(cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-values $VAL 2>/dev/null || \
              cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-value $VAL 2>/dev/null || echo "null")
    if [[ $TEMPVAL =~ ^.*\,.*$ ]]; then
        IFS=',' read -r -a TEMPVALSPLIT <<< "$TEMPVAL"
        for (( z=${#TEMPVALSPLIT[@]}-1; z>=0; z--)); do
            HOSTS+=($(parseIP "${TEMPVALSPLIT[$z]}"))
        done
    else
        HOSTS+=($(parseIP "${TEMPVAL}"))
    fi

    printf "%s\n" "${HOSTS[@]}" | sort -u | grep -v null
}



if [ $arg_wipe == "wipe" ];
        then
                echo "Wiping Environment...."
        else
                echo "Need Args [0]=wipe "
                echo "Example: ./p1-0-wipe-env.sh wipe ..."
                exit 1
fi

#Detect & Clean DataStore(s)
if [ ! -f deploy-photon/manifests/photon/$photon_manifest ]; then
    echo "Error: Photon Manifest not found!  I got this value for \$photon_manifest="$photon_manifest
    exit 1
fi

# How Many Hosts subvalues exist in the Manifest
HOST_COUNT=$(cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-values hosts | grep address_ranges | wc -l)

#Grab Host IP Addresses & PowerOff/Unregister VMS
for (( x=${HOST_COUNT}-1; x>=0; x--)); do
    declare -a HOSTS=()
    HOSTS+=($(parseHostBlockIP "$x"))

    ESX_USER=$(cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-value hosts.$x.username)
    ESX_PASSWD=$(cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-value hosts.$x.password)

    # PowerOff/Unregister VMS
    for h in ${HOSTS[@]}; do
        echo "Removing VMs From host=$h ..."
        for VM in $(vmware-cmd -U $ESX_USER -P $ESX_PASSWD --server $h -l | grep -v "vRLI"); do
            if [ $VM != "No virtual machine found." ]; then
                vmware-cmd -U $ESX_USER -P $ESX_PASSWD --server $h $VM stop hard
                vmware-cmd -U $ESX_USER -P $ESX_PASSWD --server $h -s unregister $VM
            fi
        done
    done
done

for (( x=${HOST_COUNT}-1; x>=0; x--)); do
    declare -a HOSTS=()
    declare -a DATASTORES=()

    HOSTS+=($(parseHostBlockIP "$x"))

    # Use shyaml to get all datastores in each host block
    declare -a VALS=()
    VALS+=(deployment.image_datastores)
    VALS+=(hosts.$x.metadata.MANAGEMENT_DATASTORE)
    VALS+=(hosts.$x.metadata.ALLOWED_DATASTORES)
    for (( y=${#VALS[@]}-1; y>=0; y--)); do
        TEMPVAL=$(cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-values ${VALS[$y]} 2>/dev/null || \
                  cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-value ${VALS[$y]} 2>/dev/null || echo "null")
        # If no ALLOWED_DATASTORES, clean up all datastores
        if [[ ${y} -eq $((${#VALS[@]}-1)) && ${TEMPVAL} == "null" ]]; then
            break
        fi
        if [[ $TEMPVAL =~ ^.*\,.*$ ]]; then
            IFS=',' read -r -a TEMPVALSPLIT <<< "$TEMPVAL"
            for (( z=${#TEMPVALSPLIT[@]}-1; z>=0; z--)); do
                DATASTORES+=(${TEMPVALSPLIT[$z]})
            done
        else
            DATASTORES+=(${TEMPVAL})
        fi
    done

    # Sort to Unique Values
    DATASTORES=($(printf "%s\n" "${DATASTORES[@]}" | sort -u | grep -v null))

    ESX_USER=$(cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-value hosts.$x.username)
    ESX_PASSWD=$(cat deploy-photon/manifests/photon/$photon_manifest | shyaml get-value hosts.$x.password)

    # Clean Datastores
    for h in ${HOSTS[@]}; do
        if [ ${#DATASTORES[@]} -eq 0 ]; then
            DATASTORES+=($(vifs --server $h --username $ESX_USER --password $ESX_PASSWD --listds | sed 1,4d))
        fi
        for d in ${DATASTORES[@]}; do
            echo "cleaning up datastore ${d} on host ${h}"
            DIRECTORIES=($(vifs --server $h --username $ESX_USER --password $ESX_PASSWD --dir "[$d]" | sed 1,4d))
            for dir in ${DIRECTORIES[@]}; do
                if [[ $dir == disk* || $dir == tmp_image* || $dir == tmp_upload* || $dir == image* || $dir == vm* || $dir == deleted_image* ]]; then
                    vifs --server $h --username $ESX_USER --password $ESX_PASSWD --rm  "[$d] $dir" --force || echo "Already Wiped"
                fi
            done
        done
    done
done
