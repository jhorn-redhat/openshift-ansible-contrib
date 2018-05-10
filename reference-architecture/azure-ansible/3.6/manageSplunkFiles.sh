#!/bin/env bash

# Azure Subscription to use
AZ_SUB="SPEC.DEV"
# Resource group for blob container
RESOURCE_GROUP="spec-platform"
# Storage Account for blob container 
STORAGE_ACCOUNT="openshiftrefarch"
STORAGE_CONTAINER="ocp-prod"
# Template that contains variables pointing to this container
FILES="splunkforwarder-7.1.0-2e75b3406c5b-linux-2.6-x86_64.rpm hon-deploymentclient-spec-prod-eastus.zip"

function usage {
  echo "Error: Requires 1 args"
  echo -e "Usage: $0 [upload|delete]"
  exit 1
}

function setup {
  tempFile="${HOME}/.az_account"
  
  echo "az login -u ${az_name}"
  # check if logged in already
  az account list -o table > ${tempFile}  2>/dev/null && grep -Eq "${AZ_SUB}" ${tempFile}
  if [[ $? != 0 ]]; then 
    echo "need to login"
    az login 
  fi

  subscription_cur=$(az account list -o table |awk '/True/ {print $3}')
  subscription_id=$(awk "/${AZ_SUB}/ {print \$3}"  ${tempFile})
  subscription_name=$(awk "/${AZ_SUB}/ {print \$1}" ${tempFile})
  az account set --subscription ${subscription_id}
 }

AZ_STORAGE_ACCESS_KEY=$(az storage account keys list -g ${RESOURCE_GROUP} -n ${STORAGE_ACCOUNT} -o table | awk '/key1/ {print $3}')

export AZURE_STORAGE_ACCESS_KEY=${AZ_STORAGE_ACCESS_KEY}
export AZURE_STORAGE_ACCOUNT=${STORAGE_ACCOUNT}

function upload() {
  # upload files to blob storage
  for file in ${FILES}; do
    az storage blob upload  -f ${file} -c ${STORAGE_CONTAINER}   -n ${file}
  done
}

function delete() {
  for file in ${FILES}; do 
    az storage blob delete  --delete-snapshots='include'  -n ${file} -c ${STORAGE_CONTAINER} 
  done
}

#if [[ $# < 1 ]]; then
#  usage
#elif  [[ $1 =~ delete|upload ]]; then
if  [[ $1 =~ delete|upload ]]; then
  setup
  CMD=$1
  echo "${CMD}ing"
  ${CMD}
  # set to previous subscripiont before exiting
  echo "Setting to previous subscription"
  az account set --subscription ${subscription_cur}
else
  usage
fi

