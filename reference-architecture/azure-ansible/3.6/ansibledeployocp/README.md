\

# OpenShift Container Platform on Azure using Ansible deployment of ARM

This repository contains a few scripts and playbooks to deploy an OpenShift Container Platform on Azure using Ansible and ARM templates. This is a helper method on the [OpenShift Container Platform on Azure reference architecture document](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/).
This ARM template is designed to deploy into an existing resourcegroup and vNet.  The vNet and subnets must be created before deployment and the ARM Template updated under 'variables' to match.  

# Setup

 1. Azure subscription with required quota limits as described in  [OpenShift Container Platform on Azure reference architecture document](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3.6_on_microsoft_azure/index#parameters_required)
 2. Create required Azure resources
	-  **Resource Group**:  Described here 
	- **vNet**:  Assign address space
			- **subnets**: **Master**, **Infra** and **Node** subnets must be created and assigned CIDRs
 3. Install Ansible 2.3+
 4. Prepare deployment server
 5. Git clone 
 6. Create service principal credentials
 7. Make a copy of vars.yaml.example -> vars.yaml and edit
 8. Deploy



# Prepare
Preparing the deployment server.

Fill out required variable file, [required variables](#parameters-required) before continuing.


## **Ansible**:

Ansible 2.3+ needs to be installed before executing the prepare playbook below.

Before running the Ansible deploy for Azure, all the dependencies needed for Azure Python API must be installed. This playbook installs azure-cli 2.0.26. The [reference-architecture/azure-ansible/3.6/ansibledeployocp/playbooks/prepare.yaml](reference-architecture/azure-ansible/3.6/ansibledeployocp/playbooks/prepare.yaml) playbook automates preparations on  `localhost` by running the command below.   You will need to 

```bash
ansible-playbook playbooks/prepare.yml -e @vars.yaml
```


## Service Principal

**Automated Process**:

A script is provided automating the manual steps below,  ```createSP.sh``` which requires 4 arguments.  A Service Principal will be created with role contributor and information will be saved to ~/.azure/credentials.   

```bash 
createSP.sh
Usage: ./createSP.sh [azure login] [azure password] [service principal name to create] [service principal password]
```
Parameters:

- **Azure Login**:  Login name for your Azure subscription 
- **Azure Password**: Login password for you Azure subscriptions
- **Service Principal Name**: Name of the Service Principal you want created. ex. "openshift-sp"
- **Service Principal Password**: Password for Service Principal being created

**Manual Process**:

**NOTE:** A serviceprincipal creation is required, see [the OCP on Azure ref. arch. document](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/#azure_active_directory_credentials) and [Use Azure CLI to create a service principal to access resources](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal-cli) for more information.

Azure credentials needs to be stored in a file at `~/.azure/credentials` with the following format (do not use quotes or double quotes):

```
[default]
subscription_id=00000000-0000-0000-0000-000000000000
tenant=11111111-1111-1111-1111-111111111111
client_id=33333333-3333-3333-3333-333333333
secret=ServicePrincipalPassword
```

Where:

* `subscription_id` and `tenant` parameters can be obtained from the azure cli:

```
sudo yum install -y nodejs
sudo npm install -g azure-cli
azure login
azure account show
info:    Executing command account show
data:    Name                        : Acme Inc.
data:    ID                          : 00000000-0000-0000-0000-000000000000
data:    State                       : Enabled
data:    Tenant ID                   : 11111111-1111-1111-1111-111111111111
data:    Is Default                  : true
data:    Environment                 : AzureCloud
data:    Has Certificate             : Yes
data:    Has Access Token            : Yes
data:    User name                   : youremail@yourcompany.com
data:     
info:    account show command OK
```

* `client_id` is the "Service Principal Name" parameter when you create the serviceprincipal:

```
$ azure ad sp create -n azureansible -p ServicePrincipalPassword

info:    Executing command ad sp create
+ Creating application ansiblelab
+ Creating service principal for application 33333333-3333-3333-3333-333333333
data:    Object Id:               44444444-4444-4444-4444-444444444444
data:    Display Name:            azureansible
data:    Service Principal Names:
data:                             33333333-3333-3333-3333-333333333
data:                             http://azureansible
info:    ad sp create command OK
```


* `secret` is the serviceprincipal password

**NOTE:** Azure credentials can be also exported as environment variables or used as ansible variables. See [Getting started with Azure](https://docs.ansible.com/ansible/guide_azure.html) in the Ansible documentation for more information.




# Deployment



## ARM Templates

A choice of two templates are provided, One template **azuredeploy.json**, requires a GIT Repo be publicly accessible for Azure to access the deployment files.   If security restrictions make this impossible another template is provided **azuredeploy.json.sa**,  this deploys using a separate resourcegroup, storage account and container to service as a repository for deployment files.  To help manage these files a script is included **manageSaFiles.sh**.  Each template is designed to deploy within an existing resourcegroup and vNet.

Below are variables that need to be updated for the ARM template(s), they must match  your environment before deploying.  

**Common Variables:**
**NOTE**: These variables need to match your existing environment.

	"osm_cluster_network_cidr": "10.29.0.0/16",
	"openshift_portal_net": "10.28.0.0/16",
	"virtualNetworkName": "changeme",
	"addressPrefix": "x.x.x.x/27",
	"infranodesubnetName": "infranode",
	"infranodesubnetPrefix": "x.x.x.x/29",
	"nodesubnetName": "node",
	"nodesubnetPrefix": "x.x.x.x/29",
	"mastersubnetName": "master",
	"mastersubnetPrefix": "x.x.x.x/28",

**AZUREDEPLOY.JSON**
Customization to the ARM template variables section needs to take place before deployment to match your environment.  The GIT repo specified in ```azuredeploy.json``` needs to be accessible for azure,  i.e. public.  

    	"variables": {
		"gituser": "jhorn-redhat",
		"branch": "master", < **UPDATE WITH BRANCH YOU'RE USING** >
		"version": "3.6",
		"baseTemplateUrl": "[concat('https://raw.githubusercontent.com/',variables('gituser'),'/openshift-ansible-contrib/',variables('branch'),'/reference-architecture/azure-ansible/',variables('version'),'/')]",

**AZUREDEPLOY.JSON.SA**
This template is designed to deploy from a storage account endpoint, a script **manageSaFiles.sh** can be used to upload and delete the deployment files. Please fill out the required variables to match your environment.
  ```"baseTemplateUrl":https://<storageaccountname_goes_here>.blob.core.windows.net/<conatiner_name_goes_here>/",```


## Parameters required

**VARS.YAML**
The ansible playbook needs some parameters to be specified. There is a [vars.yaml example file](vars.yaml.example) included in this repository that should be customized with your environment data.

```
$ cp vars.yaml.example vars.yaml
$ vim vars.yaml
```

**NOTE:** The parameters detailed description can be found in [the official documentation](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/#provision_the_emphasis_role_strong_openshift_container_platform_emphasis_environment)

 * **sshkeydata**: id_rsa.pub content
 * **sshprivatedata**: id_rsa content in base64 without \n characters 
	 * `cat ~/.ssh/id_rsa | base64 | tr -d '\n'`
 * **adminusername**: User that will be created to login via ssh and as OCP cluster-admin
 * **adminpassword**: Password for the user created (in plain text)
 * **rhsmusernamepasswordoractivationkey**: 
	 * If "**usernamepassword**", then the username and password should be specified
	 * If "**activationkey**", then the activation key and organization id should be specified
 * **rhnusername**: The RHN username where the instances will be registered
 * **rhnusername**: "organizationid" if  *activationkey* method has been chosen
 * **rhnpassword**: The RHN password where the instances will be registered in plain text
 * **rhnpassword**: "activationkey" if *activationkey* method has been chosen
 * **subscriptionpoolid**: The subscription pool id the instances will use
 * **resourcegroupname**: The Azure resource name that will be created
 * **aadclientid**: Active Directory ID needed to be able to create, move and delete persistent volumes
 * **aadclientsecret**: The Active Directory Password to match the AAD Client ID
 * **wildcardzone**: Subdomain for applications in the OpenShift cluster 
	* just zone name not FQDN, ex. "**dev**"
	* **FQDN** of the application load balancer is set using this variable. 
	*  ex. " {{ wildcard }}.{{ location }}.clouapps.azure.com ". This must be unique in azures region.

**OPTIONAL:**  
These variables if unset default to using nip.io 

 * **domain**: ex. "example.com" 
 * **nameserver**: nameserver that resolves "domain" above
 *  **customdns**:  Used to resolve {{ domain }} with {{ nameserver }} in dnsmaq.  Enables nodes/pods to resolve domains outside of vNet.
 * **fqdn**:  this is the wildcard FQDN , ex. 'dev.example.com'
 * **masterurl**:  Console address, ex. 'console.{{ fqdn }}'
* **identityproviders**: base64 string, defaults to  htpasswd
	* ``echo "[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]" | base64 ``

These Variables deploy named certificates when using the domains above, "FQDN" (wildcard) and "MASTERURL" (console). 

 - Comment out if not using,  Defaults to self-signed.
 - Paste the output for each file into the respective variables if using named certs.
	`cat <certfile> |base64 | tr -d '\n`
	 - **routercertdata**: "" 
	 - **routerkeydata**: "" 
	 - **routercadata**: "" 
	 - **mastercertdata**: ""
	 - **masterkeydata**: ""
	 - **mastercadata**: ""
- **numberofnodes**: From 3 to 30 nodes
 - **image**: The operating system image that will be used to create the instances, defaults to "**rhel**"
 - **mastervmsize**: Master nodes VM size, defaults to "**Standard_DS4_v2**"
 - **infranodesize**: Infrastructure nodes VM size, defaults to "**Standard_DS4_v2**"
 - **nodevmsize**: Application nodes VM size, defaults to "**Standard_DS4_v2**"
 - **location**:  region for deployment, defaults to **westus** 
 - **openshiftsdn**: SDN used by OCP. "**redhat/openshift-ovs-multitenant**" by default
 - **metrics**: true to enable cluster metrics, false to not enable (note, do not quote as those variables are boolean values, not strings), **true** by default
 - **logging**: true to enable cluster logging, false to not enable (note, do not quote as those variables are boolean values, not strings), **true** by default
 - **opslogging**: true to enable ops cluster logging, false to not enable (note, do not quote as those variables are boolean values, not strings), **false** by default

**

**Encrypting VARS.YAML**
Using ansible-vault to encrypt the  variable file, (vars.yaml) provides a secure way of storing sensitive data.  A environment variable needs to be set that points to where the password is stored, outside of SCM that will be used for decryption.

```<git clone dir>/reference-architecture/azure-ansible/3.6/ansibledeployocp/.vault_pass.py``` references the environment variable exported in .bashrc,   
```
ANSIBLE_VAULT_PASSWORD_FILE=/path/to/passwd/file
```
**Encrypting**
```
cd <git clone dir>/reference-architecture/azure-ansible/3.6/ansibledeployocp/
ansible-vault encrypt vars.yaml
```
**Edit**
```
ansible-vault edit vars.yaml
```

## Running the deploy

Ensure you're logged into azure cli
```bash
azure login
```
Then execute the installation

```bash
ansible-playbook -e @vars.yaml playbooks/deploy.yaml
```

**NOTE:** Ansible version should be > 2.1 as the Azure module was included in that version

### Sample Output

```bash
$ scripts/run.sh  

PLAY [localhost] ****************************************************************************************************************************************

TASK [Destroy Azure Deploy] *****************************************************************************************************************************
changed: [localhost]

TASK [Destroy Azure Deploy] *****************************************************************************************************************************
ok: [localhost]

TASK [Create Azure Deploy] ******************************************************************************************************************************
changed: [localhost]

PLAY RECAP **********************************************************************************************************************************************
localhost                  : ok=3    changed=2    unreachable=0    failed=0    
```


## Removing
**NOTE**:  when removing or re-deploying the resource group will not be deleted,  everything except the vNet and routing table are destroyed.  
```bash
ansible-playbook -e @vars.yaml playbooks/destroy.yaml
```


