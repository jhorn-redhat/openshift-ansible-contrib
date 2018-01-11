#!/bin/env bash

RESOURCE_GROUP="openshift-rg"
STORAGE_ACCOUNT="openshiftrefarch"
STORAGE_CONTAINER="ocp-lab"
ARM_TEMPLATE="azuredeploy.json.sa"
FILES="${ARM_TEMPLATE}  azuredeploy.parameters.json bastion.json bastion.sh infranode.json master.json master.sh node.sh node.json"
AZ_STORAGE_ACCESS_KEY=$(azure storage account keys list -g ${RESOURCE_GROUP} ${STORAGE_ACCOUNT} |awk '/key1/ {print $3}')

export AZURE_STORAGE_ACCESS_KEY=${AZ_STORAGE_ACCESS_KEY}
export AZURE_STORAGE_ACCOUNT=${STORAGE_ACCOUNT}

# upload files to blob storage
for file in ${FILES}; do
  azure storage blob upload ${file} ${STORAGE_CONTAINER}
done
