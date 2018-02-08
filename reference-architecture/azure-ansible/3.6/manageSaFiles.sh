#!/bin/env bash

# Resource group for blob container
RESOURCE_GROUP="openshift-rg"
# Storage Account for blob container 
STORAGE_ACCOUNT="openshiftrefarch"
STORAGE_CONTAINER="ocp-dev"
# Template that contains variables pointing to this container
ARM_TEMPLATE="azuredeploy.json.sa"
#FILES="${ARM_TEMPLATE}  azuredeploy.parameters.json bastion.json bastion.sh infranode.json master.json master.sh node.sh node.json test.json"
FILES="test.json"


function upload() {
# upload files to blob storage
for file in ${FILES}; do
  echo "Uploading ${file}"
  az storage blob upload  -f ${file} -c ${STORAGE_CONTAINER}   -n ${file}
done
}

function delete() {
  for file in ${FILES}; do 
    echo "deleting ${file}"
    az storage blob delete  --delete-snapshots='include'  -n ${file} -c ${STORAGE_CONTAINER} 
  done
}

if [[ -z ${RESOURCE_GROUP} || -z ${STORAGE_ACCOUNT} || -z ${STORAGE_CONTAINER} || -z ${ARM_TEMPLATE} ]]; then
  echo "Missing: Required Variables are not filled out correctly"
  echo "Please fillout [RESOURCE_GROUP] [STORAGE_ACCOUNT] [STORAGE_CONTAINER] [ARM_TEMPLATE[azuredeploy.json.sa|azuredeploy.json]]"
  exit
fi

if [[ $1 =~ delete|upload ]]; then
  CMD=$1
else
  echo "Usage: $0 upload|delete"
  exit 1
fi

AZ_STORAGE_ACCESS_KEY=$(az storage account keys list -g ${RESOURCE_GROUP} -n ${STORAGE_ACCOUNT} -o table | awk '/key1/ {print $3}')
export AZURE_STORAGE_ACCESS_KEY=${AZ_STORAGE_ACCESS_KEY}
export AZURE_STORAGE_ACCOUNT=${STORAGE_ACCOUNT}

echo "${CMD}ing"
${CMD}
