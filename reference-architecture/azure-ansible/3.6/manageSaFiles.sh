#!/bin/env bash

# Resource group for blob container
RESOURCE_GROUP="openshift-rg"
# Storage Account for blob container 
STORAGE_ACCOUNT="openshiftrefarch"
STORAGE_CONTAINER="ocp-lab"
# Template that contains variables pointing to this container
ARM_TEMPLATE="azuredeploy.json.sa"
FILES="${ARM_TEMPLATE}  azuredeploy.parameters.json bastion.json bastion.sh infranode.json master.json master.sh node.sh node.json"
AZ_STORAGE_ACCESS_KEY=$(azure storage account keys list -g ${RESOURCE_GROUP} ${STORAGE_ACCOUNT} |awk '/key1/ {print $3}')

export AZURE_STORAGE_ACCESS_KEY=${AZ_STORAGE_ACCESS_KEY}
export AZURE_STORAGE_ACCOUNT=${STORAGE_ACCOUNT}

function upload() {
# upload files to blob storage
for file in ${FILES}; do
  azure storage blob upload -q ${file} ${STORAGE_CONTAINER}
done
}

function delete() {
for file in ${FILES}; do
  azure storage blob delete  --delete-snapshots='include' -q  ${STORAGE_CONTAINER} ${file}
done
}

if  [[ $1 =~ delete|upload ]]; then
  CMD=$1
else
  echo "Usage: $0 upload|delete"
  exit 1
fi

echo "${CMD}ing"
${CMD}
