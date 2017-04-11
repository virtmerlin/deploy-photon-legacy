# Overview

This repo contains a pipleine that can be leveraged to deploy PCF+Photon on top of a pre-existing set of ESX clusters

## Pre-Requisites


* Photon: ESX Hosts (not managed by vCenter & Sized to PCF guidelines [here](http://pcfsizer.cfapps.pez.pivotal.io)).
* Photon: Consistent portgroup(s) across all ESX hosts fro PCF Deployment Network.
* Concourse: S3 Bucket & AWS Key/Secret with access
* Concourse: A concourse instance where worker nodes have access to dockerhub, github, & pivnet

## Steps to use this pipeline

1. `git clone git@github.com:virtmerlin/deploy-photon.git` to clone the repo
2. edit the **pipeline parameters** yml for your environment (see below for example)
3. create photon.yml for your photon deployment and place in *deploy-photon/manifests/photon*
4. create cf.yml for your photon deployment and place in *deploy-photon/manifests/pcf*
5. `fly -t [target] set-pipeline -p deploy-photon -c deploy-photon/ci/pipeline.yml -l parameters.yml` to setup the pipeline



## Pipeline Parameters

``` 

### Concourse Objects
## Concourse Required Params

# Semver file name to trigger full pipeline builds
semver_file_name: [filename]

# aws creds for semver s3 bucket
aws_id: [aws id]
aws_key: [aws secret] 

# github RSA private key for git resources
githubsshkey: |-
  -----BEGIN RSA PRIVATE KEY-----
  [priv key]
  -----END RSA PRIVATE KEY-----

### Bosh & CF Object Params
## Bosh

# Bosh manifest template located in git repo manifests/bosh
bosh_manifest: bosh-template-v1.yml

# Bosh manifest network params
bosh_cpi: photon
bosh_deployment_network_name: boshNetwork
bosh_deployment_network: Photon_PCF
bosh_deployment_network_subnet: "10.65.170.0/24"
bosh_deployment_network_gw: 10.65.170.1
bosh_deployment_network_dns: 10.65.162.2
bosh_deployment_network_ip: 10.65.170.9
bosh_deployment_user: admin
bosh_deployment_passwd: admin

# PCF deployment params
pcf_ert_version: 1.7.0
pcf_deployment_network: Photon_PCF
pcf_pivnet_token: [pivnet token]
pcf_manifest: cf-pezlab.yml

### Bosh CPI Specific Params
## Photon

# ESX Params for Photon Hosts
esx_user: root
esx_passwd: "d3v0ps!"
esx_hosts: 10.65.162.104,10.65.162.106-10.65.162.107,10.65.162.110

# wipe-env.sh arg
arg_wipe: wipe

# Photon manifest template
photon_manifest: photon-pezlab.yml

# Param for which CPI to build : example [latest|0.8.0|0.8.0.u1|0.9.0]
photon_release: latest

# Param for Photon Platform CLI download url
cli_url: [cli download url]

# Params for Photon Platform auth user
photon_user: dev
photon_passwd: photon
photon_ignore_cert: true

# Params for Photon Platform tenant & project
photon_tenant: pezlab-tenant
photon_project: pezlab-proj

# Params for ovftool to install "photon-installer"
ova_url: [installer ova download url]
ova_network: Mgmt
ova_datastore: FS_PEZ_NFS_HAAS04
ova_ip: 10.65.162.14
ova_netmask: 255.255.255.0
ova_gateway: 10.65.162.1
ova_dns: 10.65.162.2
ova_ntp: 0.pool.ntp.org
ova_syslog: 10.65.162.15
ova_passwd: photon
ova_esx_user: root
ova_esx_passwd: [passwd]
ova_esx_host: 10.65.162.104
```

