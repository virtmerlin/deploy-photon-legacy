#!/bin/bash
set -x

# target BOSH
bosh -n target https://${bosh_deployment_network_ip}
bosh -n login ${bosh_deployment_user} ${bosh_deployment_passwd}

# run errands
ERRORS=()
SUCCESSES=()
for deployment in `bosh deployments | awk '{print $2;}'  | egrep -v "Acting|Name|total" | grep -v '|'  | tr "\n" " "` ; do
	bosh download manifest $deployment > /tmp/$deployment-manifest-$$.yml
	bosh deployment /tmp/$deployment-manifest-$$.yml
	for errand in `bosh errands | awk '{print $2;}' | egrep -v "Name" | tr "\n" " "` ; do
		echo $errand | egrep "^(smoke-tests|acceptance-tests|push-apps-manager|push-app-usage-service|autoscaling|autoscaling-register-broker)$" 2>&1 > /dev/null
		if [[ $? -ne 0 ]] ; then
			echo "Skipping errand $errand"
		else
			bosh run errand $errand
			if [[ $? -eq 0 ]] ; then
				SUCCESSES+=("$errand completed successfully")
			else
				ERRORS+=("$errand failed see output above")
			fi
		fi
	done
done


for ((i=0; i < ${#SUCCESSES[@]} ; i++ )) ;do
	echo ${SUCCESSES[$s]}
done

for ((i=0; i < ${#ERRORS[@]} ; i++ )) ;do
	echo ${ERRORS[$i]}
done

if [[ 0 -ne ${#ERRORS[@]} ]] ; then
	exit 1;
fi
