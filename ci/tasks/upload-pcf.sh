#!/bin/bash
set -e

#TMP DEBUG VARS
#pcf_pivnet_token=[token]
#bosh_deployment_network_ip="[IP]"
#bosh_deployment_user=admin
#bosh_deployment_passwd=[passwd]
#bosh_cpi=photon
################

  if [ -z $1 ] ; then
        >2& echo "ERROR, deploy-pcf.sh needs something to install"
        >2& echo "usage:  deploy-pcf.sh [ pivnet_release_name ] [ version | latest ]"
        >2& echo "example: deploy-pcf.sh elastic-runtime latest"
        exit 1
  fi


### If latest version is asked for, grab it from Pivnet else look for the given version

  if [[ $2 == "latest" ]]; then
      PIVNET_REL_VERSION=$(curl -s -X GET https://network.pivotal.io/api/v2/products/${1}/releases | jq '[.releases[].version]' | grep '[0-9].[0-9].[0-9]' | sort -r | head -1 | tr -d '"' | tr -d ',' | tr -d ' ')
  else
      PIVNET_REL_VERSION=$2
  fi

  CMD="curl -s -X GET https://network.pivotal.io/api/v2/products/$1/releases | jq ' .releases[] | select(.version == \"$PIVNET_REL_VERSION\") | .id'"
  PIVNET_REL_ID=$(eval $CMD)


### Get Download Link & MD5

  case $1 in
    elastic-runtime)
      DOWNLOAD_NAME="PCF Elastic Runtime"
      ;;
    *)
      echo "deploy-pcf.sh doesnt support $1 "
      exit 1
  esac

  #-----
  CMD="curl -s -X GET https://network.pivotal.io/api/v2/products/$1/releases/$PIVNET_REL_ID/product_files | jq ' .product_files[] | select(.name == \"$DOWNLOAD_NAME\") | ._links.download.href'"
  PIVNET_LINK=$(eval $CMD | tr -d '"')
  #-----
  CMD="curl -s -X GET https://network.pivotal.io/api/v2/products/$1/releases/$PIVNET_REL_ID/product_files | jq ' .product_files[] | select(.name == \"$DOWNLOAD_NAME\") | ._links.self.href'"
  PIVNET_SELF=$(eval $CMD | tr -d '"')
  #-----
  PIVNET_MD5=$(curl -s ${PIVNET_SELF} | jq ' .product_file.md5' | tr -d '"')


### Download, check md5, & Unpack Tile

  # mkdir to place the tile
  if [ ! -d /tmp/${1} ]; then
    mkdir /tmp/${1}
  fi
  cd /tmp/${1}

  # test if tile exists, if not download
  echo "Downloading $1 $PIVNET_REL_VERSION version from $PIVNET_LINK with md5=$PIVNET_MD5..."
  curl -H "Authorization: Token ${pcf_pivnet_token}"  -X POST https://network.pivotal.io/api/v2/products/$1/releases/$PIVNET_REL_ID/eula_acceptance
  echo
  if [ ! -f /tmp/${1}/${1}-${PIVNET_REL_VERSION}.pivotal ]; then
   wget -O /tmp/${1}/${1}-${PIVNET_REL_VERSION}.pivotal --post-data="" --header="Authorization: Token ${pcf_pivnet_token}" ${PIVNET_LINK}
  fi

  # get md5 of the downloaded file
  PIVNET_MD5_DL=$(openssl md5 /tmp/${1}/${1}-${PIVNET_REL_VERSION}.pivotal | awk -F "= " '{print$2}')

  # test if md5 matches, if true; then unzip
  if [ ${PIVNET_MD5_DL} != ${PIVNET_MD5} ]; then
    echo "ERROR, MD5 does not match for ${1}-${PIVNET_REL_VERSION}.pivotal"
    exit 1
  else
    echo "MD5 matches for ${1}-${PIVNET_REL_VERSION}.pivotal"
  fi

  unzip ${1}-${PIVNET_REL_VERSION}.pivotal
  cd /tmp/${1}/releases

### Upload Releases to BOSH
  bosh -n target https://${bosh_deployment_network_ip}
  bosh -n login ${bosh_deployment_user} ${bosh_deployment_passwd}

  cd /tmp/$1/releases
  for f in `ls` ; do
    bosh -n upload release $f
  done

### Get Stemcell & Upload it to BOSH

  # Set correct stemcell search string

  case ${bosh_cpi} in
    photon)
      STEMCELL_CPI="vsphere"
      ;;
    *)
      echo "deploy-pcf.sh doesnt support ${bosh_cpi} yet "
      exit 1
  esac

  #----
  STEMCELL_VER=$(cat /tmp/$1/metadata/cf.yml | shyaml get-value stemcell_criteria.version)
  #----
  CMD="curl -s -X GET https://network.pivotal.io/api/v2/products/stemcells/releases | jq ' .releases[] | select(.version == \"${STEMCELL_VER}\") | .id'"
  STEMCELL_REL_ID=$(eval $CMD | tr -d '"')
  #----
  CMD="curl -s -X GET https://network.pivotal.io/api/v2/products/stemcells/releases | jq ' .releases[] | select(.version == \"${STEMCELL_VER}\") | ._links.eula_acceptance.href '"
  STEMCELL_EULA=$(eval $CMD | tr -d '"')
  #----
  CMD="curl -s https://network.pivotal.io/api/v2/products/stemcells/releases/${STEMCELL_REL_ID}/product_files | jq ' .product_files[] | .name' | grep -i ${STEMCELL_CPI} "
  STEMCELL_OS=$(eval $CMD | tr -d '"')
  #----
  CMD="curl -s https://network.pivotal.io/api/v2/products/stemcells/releases/${STEMCELL_REL_ID}/product_files | jq ' .product_files[] | select(.name == \"${STEMCELL_OS}\") | ._links.download.href '"
  STEMCELL_LINK=$(eval $CMD | tr -d '"')
  #----
  CMD="curl -s https://network.pivotal.io/api/v2/products/stemcells/releases/${STEMCELL_REL_ID}/product_files | jq ' .product_files[] | select(.name == \"${STEMCELL_OS}\") | ._links.self.href '"
  STEMCELL_SELF=$(eval $CMD | tr -d '"')
  #----
  STEMCELL_MD5=$(curl -s ${STEMCELL_SELF} | jq ' .product_file.md5' | tr -d '"')

  # Check that Photon reqs are met from stemcell version
  if [[ ${STEMCELL_VER} -lt 3177 && ${bosh_cpi} == "photon" ]]; then
    echo "ERROR, Photon requires stemcell => vsphere 3177"
    exit 1
  fi

  # test if stemcell exists, if not download
  echo "Downloading ${STEMCELL_CPI} Stemcell version ${STEMCELL_VER} from ${STEMCELL_LINK} with md5=$STEMCELL_MD5..."
  if [[ ! -f /tmp/${1}/stemcell-${STEMCELL_CPI}-${STEMCELL_VER}.tgz ]]; then
    curl -H "Authorization: Token ${pcf_pivnet_token}"  -X POST ${STEMCELL_EULA}
    wget -O /tmp/${1}/stemcell-${STEMCELL_CPI}-${STEMCELL_VER}.tgz --post-data="" --header="Authorization: Token ${pcf_pivnet_token}" ${STEMCELL_LINK}
  fi

  # get md5 of the downloaded stemcell
  STEMCELL_MD5_DL=$(openssl md5 /tmp/${1}/stemcell-${STEMCELL_CPI}-${STEMCELL_VER}.tgz | awk -F "= " '{print$2}')

  # test if md5 matches, if true; then upload
  if [ ${STEMCELL_MD5_DL} != ${STEMCELL_MD5} ]; then
    echo "ERROR, MD5 does not match for /tmp/${1}/stemcell-${STEMCELL_CPI}-${STEMCELL_VER}.tgz"
    exit 1
  else
    echo "MD5 matches for /tmp/${1}/stemcell-${STEMCELL_CPI}-${STEMCELL_VER}.tgz"
    bosh -n upload stemcell /tmp/${1}/stemcell-${STEMCELL_CPI}-${STEMCELL_VER}.tgz --skip-if-exists
  fi
