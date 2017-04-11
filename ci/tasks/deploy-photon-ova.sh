#!/bin/bash +x
set -e

#Get Latest Photon Installer
echo "Downloading PHOTON Installer ova..."
if [[ $ova_url == "latest" || -z "$ova_url" ]]; then
  echo "Using default url."
  ova_url=$(wget -q -O- https://github.com/vmware/photon-controller/wiki/download | grep "install-vm.ova" | egrep -o http.*\" | tr -d "\"")
fi
wget ${ova_url} -O /tmp/installer-vm.ova

ovftool --acceptAllEulas --noSSLVerify --skipManifestCheck \
--X:injectOvfEnv --overwrite --powerOffTarget --powerOn \
--diskMode=thin \
--net:"NAT"="${ova_network}" \
--datastore=${ova_datastore} \
--name=photon-installer \
--prop:ip0=${ova_ip} \
--prop:netmask0=${ova_netmask} \
--prop:gateway=${ova_gateway} \
--prop:DNS=${ova_dns} \
--prop:ntp_servers=${ova_ntp} \
--prop:enable_syslog="true" \
--prop:syslog_endpoint=${ova_syslog} \
--prop:admin_password=${ova_passwd} /tmp/installer-vm.ova \
vi://${ova_esx_user}:${ova_esx_passwd}@${ova_esx_host}
echo "sleeping 3 minutes while Photon-Installer ova Powers On"
sleep 180
