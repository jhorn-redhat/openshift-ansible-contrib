#!/bin/bash
# $1 is resource group name
# $2 is the password
# $3 is subscription
sp_name=${1}
sp_pass=${2}

# handled with playbook prepare
#yum -y install wget
#wget -c https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
#rpm -ivh epel-release-latest-7.noarch.rpm
#yum install -y npm python2-pip gcc python-devel &&
#pip install --upgrade pip && pip install azure-cli

#az login
az account show > .az_account
subscription_id=$(awk -F'"' '/\"id\"\:/ {print $4}' .az_account)
client_id=$(az ad app show --id "http://${sp_name}"|awk -F'"' '/appId/  {print $4}')
tenant_id=$(az account show|awk -F'"' '/\"tenantId"\:/ {print $4}' .az_account)

echo "$subscription_id"
az ad sp create-for-rbac -n ${sp_name} --role contributor --password ${sp_pass} \
 --scope /subscriptions/${subscription_id}

echo "Creating Credentials ~/.azure/credentials"
cat >  ~/.azure/credentials <<EOF
[default]
subscription_id=${subscription_id}
tenant=${tenant_id}
client_id=${client_id}
secret=${sp_pass}
EOF
