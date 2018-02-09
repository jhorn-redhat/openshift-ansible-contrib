---


---

<h1 id="openshift-container-platform-on-azure-using-ansible-deployment-of-arm">OpenShift Container Platform on Azure using Ansible deployment of ARM</h1>
<p>This repository contains a few scripts and playbooks to deploy an OpenShift Container Platform on Azure using Ansible and ARM templates. This is a helper method on the <a href="https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/">OpenShift Container Platform on Azure reference architecture document</a>.<br>
This ARM template is designed to deploy into an existing resourcegroup and vNet.  The vNet and subnets must be created before deployment and the ARM Template updated under ‘variables’ to match.</p>
<h1 id="setup">Setup</h1>
<ol>
<li>Azure subscription with required quota limits as described in  <a href="https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3.6_on_microsoft_azure/index#parameters_required">OpenShift Container Platform on Azure reference architecture document</a></li>
<li>Create required Azure resources
<ul>
<li><strong>Resource Group</strong>:  Described here</li>
<li><strong>vNet</strong>:  Assign address space<br>
- <strong>subnets</strong>: <strong>Master</strong>, <strong>Infra</strong> and <strong>Node</strong> subnets must be created and assigned CIDRs</li>
</ul>
</li>
<li>Install Ansible 2.3+</li>
<li>Prepare deployment server</li>
<li>Create service principal credentials</li>
<li>Make a copy of vars.yaml.example -&gt; vars.yaml and edit</li>
<li>Deploy</li>
</ol>
<h1 id="prepare">Prepare</h1>
<p>Preparing the deployment server.</p>
<p>Fill out required variable file, <a href="#parameters-required">required variables</a> before continuing.</p>
<h2 id="ansible"><strong>Ansible</strong>:</h2>
<p>Ansible 2.3+ needs to be installed before executing the prepare playbook below.</p>
<p>Before running the Ansible deploy for Azure, all the dependencies needed for Azure Python API must be installed. This playbook installs azure-cli 2.0.26. The <a href="reference-architecture/azure-ansible/3.6/ansibledeployocp/playbooks/prepare.yaml">reference-architecture/azure-ansible/3.6/ansibledeployocp/playbooks/prepare.yaml</a> playbook automates preparations on  <code>localhost</code> by running the command below.   You will need to</p>
<pre class=" language-bash"><code class="prism  language-bash">ansible-playbook playbooks/prepare.yml -e @vars.yaml
</code></pre>
<h2 id="service-principal">Service Principal</h2>
<p><strong>Automated Process</strong>:</p>
<p>A script is provided automating the manual steps below,  <code>createSP.sh</code> which requires 4 arguments.  A Service Principal will be created with role contributor and information will be saved to ~/.azure/credentials.</p>
<pre class=" language-bash"><code class="prism  language-bash">createSP.sh
Usage: ./createSP.sh <span class="token punctuation">[</span>azure login<span class="token punctuation">]</span> <span class="token punctuation">[</span>azure password<span class="token punctuation">]</span> <span class="token punctuation">[</span>service principal name to create<span class="token punctuation">]</span> <span class="token punctuation">[</span>service principal password<span class="token punctuation">]</span>
</code></pre>
<p>Parameters:</p>
<ul>
<li><strong>Azure Login</strong>:  Login name for your Azure subscription</li>
<li><strong>Azure Password</strong>: Login password for you Azure subscriptions</li>
<li><strong>Service Principal Name</strong>: Name of the Service Principal you want created. ex. “openshift-sp”</li>
<li><strong>Service Principal Password</strong>: Password for Service Principal being created</li>
</ul>
<p><strong>Manual Process</strong>:</p>
<p><strong>NOTE:</strong> A serviceprincipal creation is required, see <a href="https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/#azure_active_directory_credentials">the OCP on Azure ref. arch. document</a> and <a href="https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal-cli">Use Azure CLI to create a service principal to access resources</a> for more information.</p>
<p>Azure credentials needs to be stored in a file at <code>~/.azure/credentials</code> with the following format (do not use quotes or double quotes):</p>
<pre><code>[default]
subscription_id=00000000-0000-0000-0000-000000000000
tenant=11111111-1111-1111-1111-111111111111
client_id=33333333-3333-3333-3333-333333333
secret=ServicePrincipalPassword
</code></pre>
<p>Where:</p>
<ul>
<li><code>subscription_id</code> and <code>tenant</code> parameters can be obtained from the azure cli:</li>
</ul>
<pre><code>sudo yum install -y nodejs
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
</code></pre>
<ul>
<li><code>client_id</code> is the “Service Principal Name” parameter when you create the serviceprincipal:</li>
</ul>
<pre><code>$ azure ad sp create -n azureansible -p ServicePrincipalPassword

info:    Executing command ad sp create
+ Creating application ansiblelab
+ Creating service principal for application 33333333-3333-3333-3333-333333333
data:    Object Id:               44444444-4444-4444-4444-444444444444
data:    Display Name:            azureansible
data:    Service Principal Names:
data:                             33333333-3333-3333-3333-333333333
data:                             http://azureansible
info:    ad sp create command OK
</code></pre>
<ul>
<li><code>secret</code> is the serviceprincipal password</li>
</ul>
<p><strong>NOTE:</strong> Azure credentials can be also exported as environment variables or used as ansible variables. See <a href="https://docs.ansible.com/ansible/guide_azure.html">Getting started with Azure</a> in the Ansible documentation for more information.</p>
<h1 id="deployment">Deployment</h1>
<h2 id="arm-templates">ARM Templates</h2>
<p>A choice of two templates are provided, One template <strong>azuredeploy.json</strong>, requires a GIT Repo be publicly accessible for Azure to access the deployment files.   If security restrictions make this impossible another template is provided <strong><a href="http://azuredeploy.json.sa">azuredeploy.json.sa</a></strong>,  this deploys using a separate resourcegroup, storage account and container to service as a repository for deployment files.  To help manage these files a script is included <strong><a href="http://manageSaFiles.sh">manageSaFiles.sh</a></strong>.  Each template is designed to deploy within an existing resourcegroup and vNet.</p>
<p>Below are variables that need to be updated for the ARM template(s), they must match  your environment before deploying.</p>
<p><strong>Common Variables:</strong><br>
<strong>NOTE</strong>: These variables need to match your existing environment.</p>
<pre><code>"osm_cluster_network_cidr": "10.29.0.0/16",
"openshift_portal_net": "10.28.0.0/16",
"virtualNetworkName": "changeme",
"addressPrefix": "x.x.x.x/27",
"infranodesubnetName": "infranode",
"infranodesubnetPrefix": "x.x.x.x/29",
"nodesubnetName": "node",
"nodesubnetPrefix": "x.x.x.x/29",
"mastersubnetName": "master",
"mastersubnetPrefix": "x.x.x.x/28",
</code></pre>
<p><strong>AZUREDEPLOY.JSON</strong><br>
Customization to the ARM template variables section needs to take place before deployment to match your environment.  The GIT repo specified in <code>azuredeploy.json</code> needs to be accessible for azure,  i.e. public.</p>
<pre><code>	"variables": {
	"gituser": "jhorn-redhat",
	"branch": "master", &lt; **UPDATE WITH BRANCH YOU'RE USING** &gt;
	"version": "3.6",
	"baseTemplateUrl": "[concat('https://raw.githubusercontent.com/',variables('gituser'),'/openshift-ansible-contrib/',variables('branch'),'/reference-architecture/azure-ansible/',variables('version'),'/')]",
</code></pre>
<p><strong><a href="http://AZUREDEPLOY.JSON.SA">AZUREDEPLOY.JSON.SA</a></strong><br>
This template is designed to deploy from a storage account endpoint, a script <strong><a href="http://manageSaFiles.sh">manageSaFiles.sh</a></strong> can be used to upload and delete the deployment files. Please fill out the required variables to match your environment.<br>
<code>"baseTemplateUrl":https://&lt;storageaccountname_goes_here&gt;.blob.core.windows.net/&lt;conatiner_name_goes_here&gt;/",</code></p>
<h2 id="parameters-required">Parameters required</h2>
<p><strong>VARS.YAML</strong><br>
The ansible playbook needs some parameters to be specified. There is a <a href="vars.yaml.example">vars.yaml example file</a> included in this repository that should be customized with your environment data.</p>
<pre><code>$ cp vars.yaml.example vars.yaml
$ vim vars.yaml
</code></pre>
<p><strong>NOTE:</strong> The parameters detailed description can be found in <a href="https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_red_hat_openshift_container_platform_3_on_microsoft_azure/#provision_the_emphasis_role_strong_openshift_container_platform_emphasis_environment">the official documentation</a></p>
<ul>
<li><strong>sshkeydata</strong>: id_rsa.pub content</li>
<li><strong>sshprivatedata</strong>: id_rsa content in base64 without \n characters
<ul>
<li><code>cat ~/.ssh/id_rsa | base64 | tr -d '\n'</code>)</li>
</ul>
</li>
<li><strong>adminusername</strong>: User that will be created to login via ssh and as OCP cluster-admin</li>
<li><strong>adminpassword</strong>: Password for the user created (in plain text)</li>
<li><strong>rhsmusernamepasswordoractivationkey</strong>:
<ul>
<li>If “<strong>usernamepassword</strong>”, then the username and password should be specified</li>
<li>If “<strong>activationkey</strong>”, then the activation key and organization id should be specified</li>
</ul>
</li>
<li><strong>rhnusername</strong>: The RHN username where the instances will be registered</li>
<li><strong>rhnusername</strong>: “organizationid” if  <em>activationkey</em> method has been chosen</li>
<li><strong>rhnpassword</strong>: The RHN password where the instances will be registered in plain text</li>
<li><strong>rhnpassword</strong>: “activationkey” if <em>activationkey</em> method has been chosen</li>
<li><strong>subscriptionpoolid</strong>: The subscription pool id the instances will use</li>
<li><strong>resourcegroupname</strong>: The Azure resource name that will be created</li>
<li><strong>aadclientid</strong>: Active Directory ID needed to be able to create, move and delete persistent volumes</li>
<li><strong>aadclientsecret</strong>: The Active Directory Password to match the AAD Client ID</li>
<li><strong>wildcardzone</strong>: Subdomain for applications in the OpenShift cluster
<ul>
<li>just zone name not FQDN, ex. “<strong>dev</strong>”</li>
<li><strong>FQDN</strong> of the application load balancer is set using this variable.</li>
<li>ex. " {{ wildcard }}.{{ location }}.clouapps.azure.com ". This must be unique in azures region.</li>
</ul>
</li>
</ul>
<p><strong>OPTIONAL:</strong><br>
These variables if unset default to using <a href="http://nip.io">nip.io</a></p>
<ul>
<li><strong>domain</strong>: ex. “<a href="http://example.com">example.com</a>”</li>
<li><strong>nameserver</strong>: nameserver that resolves “domain” above</li>
<li><strong>customdns</strong>:  Used to resolve {{ domain }} with {{ nameserver }} in dnsmaq.  Enables nodes/pods to resolve domains outside of vNet.</li>
<li><strong>fqdn</strong>:  this is the wildcard FQDN , ex. ‘<a href="http://dev.example.com">dev.example.com</a>’</li>
<li><strong>masterurl</strong>:  Console address, ex. ‘console.{{ fqdn }}’</li>
</ul>
<p>These Variables deploy named certificates when using the domains above, “FQDN” (wildcard) and “MASTERURL” (console).</p>
<ul>
<li>Comment out if not using,  Defaults to self-signed.</li>
<li>Paste the output for each file into the respective variables if using named certs.<br>
<code>cat &lt;certfile&gt; |base64 | tr -d '\n</code>
<ul>
<li><strong>routercertdata</strong>: “”</li>
<li><strong>routerkeydata</strong>: “”</li>
<li><strong>routercadata</strong>: “”</li>
<li><strong>mastercertdata</strong>: “”</li>
<li><strong>masterkeydata</strong>: “”</li>
<li><strong>mastercadata</strong>: “”</li>
</ul>
</li>
<li><strong>numberofnodes</strong>: From 3 to 30 nodes</li>
<li><strong>image</strong>: The operating system image that will be used to create the instances, defaults to “<strong>rhel</strong>”</li>
<li><strong>mastervmsize</strong>: Master nodes VM size, defaults to “<strong>Standard_DS4_v2</strong>”</li>
<li><strong>infranodesize</strong>: Infrastructure nodes VM size, defaults to “<strong>Standard_DS4_v2</strong>”</li>
<li><strong>nodevmsize</strong>: Application nodes VM size, defaults to “<strong>Standard_DS4_v2</strong>”</li>
<li><strong>location</strong>:  region for deployment, defaults to <strong>westus</strong></li>
<li><strong>openshiftsdn</strong>: SDN used by OCP. “<strong>redhat/openshift-ovs-multitenant</strong>” by default</li>
<li><strong>metrics</strong>: true to enable cluster metrics, false to not enable (note, do not quote as those variables are boolean values, not strings), <strong>true</strong> by default</li>
<li><strong>logging</strong>: true to enable cluster logging, false to not enable (note, do not quote as those variables are boolean values, not strings), <strong>true</strong> by default</li>
<li><strong>opslogging</strong>: true to enable ops cluster logging, false to not enable (note, do not quote as those variables are boolean values, not strings), <strong>false</strong> by default</li>
</ul>
<h2 id="running-the-deploy">Running the deploy</h2>
<pre class=" language-bash"><code class="prism  language-bash">ansible-playbook -e @vars.yaml playbooks/deploy.yml
</code></pre>
<p><strong>NOTE:</strong> Ansible version should be &gt; 2.1 as the Azure module was included in that version</p>
<h3 id="sample-output">Sample Output</h3>
<pre class=" language-bash"><code class="prism  language-bash">$ scripts/run.sh  

PLAY <span class="token punctuation">[</span>localhost<span class="token punctuation">]</span> ****************************************************************************************************************************************

TASK <span class="token punctuation">[</span>Destroy Azure Deploy<span class="token punctuation">]</span> *****************************************************************************************************************************
changed: <span class="token punctuation">[</span>localhost<span class="token punctuation">]</span>

TASK <span class="token punctuation">[</span>Destroy Azure Deploy<span class="token punctuation">]</span> *****************************************************************************************************************************
ok: <span class="token punctuation">[</span>localhost<span class="token punctuation">]</span>

TASK <span class="token punctuation">[</span>Create Azure Deploy<span class="token punctuation">]</span> ******************************************************************************************************************************
changed: <span class="token punctuation">[</span>localhost<span class="token punctuation">]</span>

PLAY RECAP **********************************************************************************************************************************************
localhost                  <span class="token keyword">:</span> ok<span class="token operator">=</span>3    changed<span class="token operator">=</span>2    unreachable<span class="token operator">=</span>0    failed<span class="token operator">=</span>0    
</code></pre>
<h2 id="removing">Removing</h2>
<p><strong>NOTE</strong>:  when removing or re-deploying the resource group will not be deleted,  everything except the vNet and routing table are destroyed.</p>
<pre class=" language-bash"><code class="prism  language-bash">ansible-playbook -e @vars.yaml playbooks/destroy.yaml
</code></pre>

