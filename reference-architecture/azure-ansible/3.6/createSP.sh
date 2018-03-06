#!/bin/bash
# $1 is azure login/user name
# $2 is azure password
# $3 is service principal name
# $4 is service principal password
# $5 is Subscription , can be string to search for or complete subscription name

# handled with playbook prepare
#yum -y install wget
#wget -c https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
#rpm -ivh epel-release-latest-7.noarch.rpm
#yum install -y npm python2-pip gcc python-devel &&
#pip install --upgrade pip && pip install azure-cli

function setup {
  tempFile="${HOME}/.az_account"

  echo "az login -u ${az_name}"
  # check if logged in already
  az account list -o table > ${tempFile}  2>/dev/null && grep -Eq "${az_sub}" ${tempFile}
  if [[ $? != 0 ]]; then
    echo "need to login"
    az login
  fi

  subscription_id=$(awk "/${az_sub}/ {print \$3}"  ${tempFile})
  subscription_name=$(awk "/${az_sub}/ {print \$1}" ${tempFile})
  az account set --subscription ${subscription_id}

  echo "Creating SP ${sp_name}"
  az ad sp create-for-rbac -n ${sp_name} --role contributor --password ${sp_pass} \
   --scope /subscriptions/${subscription_id}
  
  client_id=$(az ad app show --id "http://${sp_name}"|awk -F'"' '/appId/  {print $4}')
  tenant_id=$(az account show|awk -F'"' '/\"tenantId"\:/ {print $4}' )
  
  echo "Creating Credentials ~/.azure/credentials"
  cat >  ~/.azure/credentials <<EOF
[${subscription_name}]
subscription_id=${subscription_id}
tenant=${tenant_id}
client_id=${client_id}
secret=${sp_pass}
EOF

  echo "Credentials:"
  echo -e "  Azure Login:      ${az_name}"
  echo -e "  Subscription ID:  ${subscription_id}"
  echo -e "  Subscription:     ${subscription_name}"
  echo -e "  Tenant ID:        ${tenant_id}"
  echo -e "  SP Name:          ${sp_name}"
  echo -e "  SP ID:            ${client_id}"

}

if [[ $# < 4 ]]; then
  echo "Error: Requires 4 args"
  echo -e "Usage: $0 [azure login] [azure password] [service principal name to create] [service principal password] [subscription  PROD|DEV ] "
else
  az_name=${1}
  az_pass=${2}
  sp_name=${3}
  sp_pass=${4}
  az_sub=${5}
  setup
fi
