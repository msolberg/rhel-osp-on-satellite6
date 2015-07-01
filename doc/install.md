# Managing Red Hat Enterprise Linux OpenStack Platform with Red Hat Satellite

## Introduction

This document serves as a guide on how to deploy and manage RHEL-OSP
with Red Hat Satellite.

## Document Conventions

This guide will present each step with instructions for both the
Graphical User interface and the Command Line interface where
possible.

## Support Statement

This reference architecture describes a supported Red Hat Enterprise
Linux OpenStack Platform 7 installation and a supported Satellite 6.1 
installation. As per the support statements for both of these
products, the resulting OpenStack is supported as well as Satellite 6,
but the Puppet code itself used to deploy OpenStack is not directly
supported. The intention of this reference architecture is provide an 
example for an organization that wishes to maintain its own Puppet
with customizations to manage OpenStack using Satellite. 

## Puppet Modules

This reference architecture uses two upstream Puppet modules to deploy
Red Hat Enterprise Linux OpenStack Platform. 

1. OpenStack Puppet Modules: Puppet modules shared between Packstack and Foreman (https://github.com/redhat-openstack/openstack-puppet-modules).
2. Astapor: Configurations to set up foreman quickly, install openstack puppet modules and rapidly provision openstack compute & controller nodes with puppet (https://github.com/redhat-openstack/astapor).

Though these modules are developed upstream by Red Hat and the Open
Source community the modules themselves are not directly supported by
Red Hat. For more infomation see the Support Statement of this
reference architecture. 

## Workflow 

Do we want to add the CICD workflow description here?

## Satellite 6 Installation

Install Satellite 6.1 or greater as per the Satellite 6 Installation Guide (https://access.redhat.com/documentation/en-US/Red_Hat_Satellite/6.0/html/Installation_Guide/index.html). Before executing `yum install katello` make the changes described in the following knowledge base article (https://access.redhat.com/solutions/1450693). 

## Preparing Content for OpenStack Deployment

### Create Lifecycle Environments

We will use a Life Cycle pattern which promomotes from Library to Development to Production. By default, the Production environment will have it's "prior" variable set to Testing so we will delete production and recreate it. 

In the Foreman UI, use the following steps to create two lifecycle environments for our OpenStack deployments.

1. Navigate to Content > Lifecycle Environments
2. In the third table click "Production"
3. Click "Remove Environment"
4. Click “+ New Environment Path” above the "Library" environment
5. Enter “Development” for the name.
6. Click Save
7. Click the “+” above the "Development" environment
8. Enter “Production” for the name.
9. Click Save

Or from the commandline:

```
hammer lifecycle-environment delete --organization='Default Organization' --name=Production
hammer lifecycle-environment create --organization='Default Organization' --name=Development --prior=Library
hammer lifecycle-environment create --organization='Default Organization' --name=Production --prior=Development
```

Optionally, delete the testing environment using a variation of the commands above. 

Verify that the environment is set up as desired with:

```
[root@foreman ~]# hammer lifecycle-environment list --organization='Default Organization'
---|-------------|------------
ID | NAME        | PRIOR      
---|-------------|------------
6  | Production  | Development
1  | Library     |            
5  | Development | Library    
---|-------------|------------
[root@foreman ~]# 
```

### Activate Your Red Hat Satellite

Download your Subscription Manifest from the Red Hat Customer Support
portal. Upon uploading the manifest to your Satellite, Red Hat
Products and Repositories will be available to sync and subscriptions
should be made available for systems to consume.

To upload your manifest, simply login to your Satellite server and:

1. navigate to Content > Subscriptions > Red Hat Subscriptions
2. Click “Import Manifest” at the top right
3. Browse to locate your manifest and click upload

From the command line: 

```
hammer subscription upload file=/path/to/manifest.zip
```

### Enable Content from Red Hat Network

The following steps will sync the required software from the Red Hat
Network to your Red Hat Satellite.

1. Navigate to Content > Red Hat Repositories.
2. Expand the “Red Hat Enterprise Linux Server” Product. 
3. Select the “Red Hat Enterprise Linux 7 Server (RPMs)” Repository Set underneath the Product. (This may take a few moments). Within that Repository Set:
   b. Select the "Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server" repository.
4. Select the "RHN Tools for Red Hat Enterprise Linux" Repository Set. Within that Repository Set:
   b. Select the "RHN Tools for Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server" repository.
5. Select the "Red Hat Enterprise Linux 7 Server - RH Common (RPMs)"
   a. Select the "Red Hat Enterprise Linux 7 Server - RH Common RPMs x86_64 7Server" repository.
5. Select the "Red Hat OpenStack" Product.
6. Select the "Red Hat OpenStack 6.0 for RHEL 7 (RPMs)" Repository Set. Within that Repository Set:
   b. Select the "Red Hat OpenStack 6.0 for RHEL 7 RPMs x86_64 7Server" repository. 

In order to kickstart systems from the Satellite server, a kickstart tree needs to be synced. 

1. On the same page (Content > Red Hat Repositories) click the "Kickstarts" tab. 
2. Select the "Red Hat Enterprise Linux Server" Product. 
3. Select the "Red Hat Enterprise Linux 7 Server (Kickstart)" Repository Set.  
4. Select the desired kickstart tree "Red Hat Enterprise Linux 7 Server Kickstart x86_64 7.1"

To perform the same actions from the command line:

TODO: Add CLI Instructions


### Sync Content from the Red Hat Network

For Red Hat Repositories or any custom Repositories with an external url defined, simply:

1. Navigate to Content > Sync Management > Sync Status
2. Expand the desired product
3. Select the desired repository
4. Click “Synchronize Now”

Sync the following repositories:

* "Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server"
* "RHN Tools for Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server"
* "Red Hat OpenStack 6.0 for RHEL 7 RPMs x86_64 7Server"
* "Red Hat Enterprise Linux 7 Server - RH Common RPMs x86_64 7Server"

### Import the OpenStack Puppet modules

Create a Product for our Puppet modules:

1. Navigate to Content > Products 
2. Click "+ New Product"

Then add a new product:

1. For name, enter "OpenStack Configuration"
2. Click Save

From the command line: 

```
hammer product create --organization='Default Organization' --name="OpenStack Configuration"
```

Next create a repository to house the Puppet modules:

1. Navigate to Content > Products 
2. Click the "OpenStack Configuration" Product
3. Click “Create Repository” on the right. 

And then add a custom repository:

1. Click "New Repository" in the upper right hand corner.
2. For name, enter "Puppet Modules"
3. Select "puppet" for Type
5. Click Save.

From the CLI:

```
hammer repository create --organization='Default Organization' --product='OpenStack Configuration' --name='Puppet Modules' --content-type=puppet
```

Next, import the quickstack puppet module from github.

Use the `pulp-puppet-module-builder` utility from the CLI to create an uploadable format from the git repository:

```
mkdir /modules
pulp-puppet-module-builder --output-dir=/modules --url=https://github.com/msolberg/astapor/ -p astapor/puppet/modules/quickstack --branch=satellite6_compat
```

Then, upload the resulting module to the OpenStack Configuration product.

```
hammer repository upload-content --name='Puppet Modules'  --path=/modules/redhat-quickstack-3.0.24.tar.gz --organization='Default Organization' --product='OpenStack Configuration'
```

Next, upload the supporting OpenStack puppet modules from StackForge:

```
git clone https://github.com/msolberg/openstack-puppet-modules -b satellite6_compat
mkdir -p /openstack-modules
pulp-puppet-module-builder --output-dir=/openstack-modules openstack-puppet-modules
hammer repository upload-content --name='Puppet Modules'  --path=/openstack-modules/ --organization='Default Organization' --product='OpenStack Configuration'
```

### Creating the OpenStack Content View

Next create a content view for our OpenStack deployment:

1. Navigate to Content > Content Views
2. Click “Create New View”
3. Enter “OpenStack” for the name
4. Click “Save”.

From the CLI:

```
hammer content-view create --organization='Default Organization' --name=OpenStack
```

Then, add the required RPM repositories to the content view:

1. Navigate to Content > Content Views
2. Click on “OpenStack”
3. Click “Yum Content” and in the submenu click “Repositories”
4. Select the following repositories to the Content View:
  * Red Hat Enterprise Linux 7 Server Kickstart x86_64 7.1
  * Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server
  * Red Hat OpenStack 6.0 for RHEL 7 RPMs x86_64 7Server
  * RHN Tools for Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server
  * Red Hat Enterprise Linux 7 Server - RH Common RPMs x86_64 7Server
5. Click "+ Add Repositories"

Add the Quickstack puppet module to the content view:

1. Click the “Puppet Modules" tab.
2. Click "+ Add New Module".
3. Click "Select a Version" next to the module named "quickstack".
4. Select the "Use Latest" version.

Follow the same procedure to import each of the StackForge puppet
modules to the content view.  Use the "add_puppet_modules.sh" script
to expedite the process.

TODO:  This should all be scripted - there are 48 of these modules!

Publish the version of the content view:

1. Click "Publish New Version"
2. Optionally enter a comment in the description field.
3. Click "Save"

TODO:  Add CLI instructions.

### Promote the OpenStack Content View

To promote the content view to the Development Lifecycle Environment, simply:

1. Click "Promote" beside “Version 1”.
2. Select the "Development" environment.
3. Click "Promote Version".

From the CLI:

```
hammer content-view version promote --version=1 --environment=Development
```

### Create an Activation Key

An activation key allows you to associate systems with a Lifecycle
and Content View during registration.

To create an Activation Key:

1. Navigate to Content > Activation Keys.
2. Click “New Activation Key” in the upper right hand corner
3. Give the name of the activation key “OpenStack_Dev”
4. Select the “Development” environment.
5. Select the "OpenStack" Content View from the drop down.
6. Click Save
7. Click Subscriptions and then click "Add"
8. Select the desired Red Hat subscriptions which include access to the “Red Hat Enterprise Linux Server OpenStack Platform” Product.
9. Select the "OpenStack Configuration" Product.
10. Click "Add Selected"

TODO: Add CLI instructions.

## Provisioning Configuration

### Associate iPXE Template

TODO: msolberg and jfulton didn't have to do this.  Maybe this is fixed in 6.1?

The Satellite 6 Bootdisk uses iPXE to simulate a PXE environment and
boot the machine. We need to configure the iPXE templates for our
specific Operating System.

1. Navigate to Hosts > Provisioning Templates.
2. Select "Kickstart default iPXE".
3. Select the "Association Tab".
4. Select "RHEL Server 7.1" in the "Applicable Operating Systems" table.
5. Click 'Submit'.
6. Navigate to Hosts > Operating Systems.
7. Select "RHEL Server 7.1".
8. Select the "Templates" tab.
9. In the iPXE dropdown choose "Kickstart default iPXE".

From the CLI:
First lookup the operating system ID:

```
hammer os list
```

And then associate the OS with the correct template (replacing n with the correct operating system id):

```
hammer template add-operatingsystem --name='Kickstart default iPXE' --
operatingsystem-id=2
hammer os add-config-template --id=n --config-template="Kickstart default iPXE"
```

### Creating the OpenStack Domains

A domain is a literal network domain such as example.com where hosts
will live. For example, a set of hosts 'controller’ and ‘compute01’ may
both exist in domain example.com. Their fully qualified domain names
would be controller.example.com and compute01.example.com respectively.

We'll create two domains, one for the Management network and one for the External network.

Create the Management domain:
1. Navigate to: Infrastructure > Domains > New Domain
2. Create a new Domain with name: ‘mgt.example.com’ (or whatever your valid domain is)
3. Enter "OpenStack Management" for the description.
4. Click on the "Locations" tab.
5. Select the "Default Location".
6. Click on the "Organizations" tab and verify that the "Default Organization" is selected organization. 
7. Click Submit.

Create the External domain:
1. Navigate to: Infrastructure > Domains > New Domain
2. Create a new Domain with name: ‘example.com’ (or whatever your valid domain is)
3. Enter "OpenStack External" for the description.
4. Click on the "Locations" tab.
5. Select the "Default Location".
6. Click on the "Organizations" tab and verify that the "Default Organization" is selected organization. 
7. Click Submit.

From the CLI:

```
hammer domain create --name=example.com
hammer organization add-domain --domain=mgt.example.com --name='Default Organization'
hammer location add-domain --domain=example.com --name='Default Location'
```

```
hammer domain create --name=example.com
hammer organization add-domain --domain=example.com --name='Default Organization'
hammer location add-domain --domain=example.com --name='Default Location'
```

From this point forward when referencing domains we will refer to example.com, but you should substitute your relevant domain.

TODO:  Shouldn't we have a DNS capsule provisioned for this?

### Creating the OpenStack Subnets

A Subnet in Satellite 6 is the definition of your actual network
subnet.  We'll be creating two subnets, one for the management network
(10.1.1.0/24) and one for the external network (192.168.1.0/24). 

To create the networks, navigate to

Infrastructure > Subnets > New Subnet

Create the Management Network by configuring the general subnet details:

1. Enter a name for the subnet (e.g. OpenStack Management) in the Name field.
2. Enter the network address of the subnet (e.g. 10.1.1.0) in the Network address field.
3. Enter the network mask for the subnet (e.g. 255.255.255.0) in the Network mask field.
4. Enter the address of a gateway (e.g. 10.1.1.1) in the Gateway address field.
5. Enter the address of the primary DNS server (e.g. 10.1.1.1), if any, in the Primary DNS server field.
6. Enter the address of the secondary DNS server, if any, in the Secondary DNS server field.
7. Select DHCP as IP address management source from the IPAM list.  Satellite will be providing DHCP for this domain to enable PXE-booting.
8. Optionally, enter the ID of a VLAN for the subnet.
9. Select DHCP as the default boot mode for interfaces assigned to the subnet from the Boot mode list. 
10. Click the Domains tab.
11. Select "mgt.example.com" as the domain for this subnet.
12. Click on the "Locations" tab.
13. Select the "Default Location".
14. Click "Submit" to create the subnet.

Create the External Network with the following settings

1. Enter a name for the subnet (e.g. OpenStack External) in the Name field.
2. Enter the network address of the subnet (e.g. 192.168.1.0) in the Network address field.
3. Enter the network mask for the subnet (e.g. 255.255.255.0) in the Network mask field.
4. Enter the address of a gateway (e.g. 192.168.1.1) in the Gateway address field.
5. Enter the address of the primary DNS server (e.g. 192.168.1.1), if any, in the Primary DNS server field.
6. Enter the address of the secondary DNS server, if any, in the Secondary DNS server field.
7. Select DHCP as IP address management source from the IPAM list.  Satellite will be providing DHCP for this domain.
8. Optionally, enter the ID of a VLAN for the subnet.
9. Select DHCP as the default boot mode for interfaces assigned to the subnet from the Boot mode list. 
10. Click the Domains tab.
11. Select "example.com" as the domain for this subnet.
12. Click on the "Locations" tab.
13. Select the "Default Location".
14. Click "Submit" to create the subnet.

From the CLI:

```
hammer subnet create --name="OpenStack Management" --network=10.1.1.0 --mask=255.255.255.0
hammer organization add-subnet --subnet="OpenStack Management" --name='Default Organization'
hammer location add-subnet --subnet="OpenStack Management" --name='Default Location'
```

```
hammer subnet create --name=mysubnet --network=192.168.1.0 --mask=255.255.255.0
hammer organization add-subnet --subnet="OpenStack External" --name='Default Organization'
hammer location add-subnet --subnet=mysubnet --name='Default Location'
```

### Creating the OpenStack Host Groups.

Host Groups are a sort of template that bring together a kickstart
template, puppet classes, content view, and environment to build an
SOE.  We'll be creating two Host Groups; one for OpenStack Controllers
and one for OpenStack Compute nodes.

To create the host groups, navigate to "Configure > Host Groups"

Create the Controller Host Group:

1. Click on "New Host Group".
2. Enter "OpenStack Controller" for the Name.
3. Select "Development" for the Lifecycle Environemnt.
4. Select "OpenStack" for the Content View.
5. Click "Reset Puppet Environment to match selected Content View" next to Puppet Environment. 
6. Select the hostname for your Satellite server for the "Content Source", "Puppet CA", and "Puppet Master".

1. Click on the "Puppet Classes" tab.
2. Search for "quickstack" in the list of Available Classes.
3. Use the "+" button to add the following classes:
  * quickstack::openstack_common
  * quickstack::pacemaker::common
  * quickstack::pacemaker::params
  * quickstack::pacemaker::keystone
  * quickstack::pacemaker::swift
  * quickstack::pacemaker::load_balancer
  * quickstack::pacemaker::memcached
  * quickstack::pacemaker::qpid
  * quickstack::pacemaker::rabbitmq
  * quickstack::pacemaker::glance
  * quickstack::pacemaker::nova
  * quickstack::pacemaker::heat
  * quickstack::pacemaker::cinder
  * quickstack::pacemaker::horizon
  * quickstack::pacemaker::galera
  * quickstack::pacemaker::neutron

1. Click on the "Network" tab.
2. Select the Management domain (e.g. "mgt.example.com") for Domain.
3. Select "OpenStack Management" for the Subnet.
4. The Realm field can be left blank 

1. Click on the "Operating System" tab.
2. Select "x86_64" for the Architecture.
3. Select "RedHat 7.1" for the Operating system.
4. Select "Default_Organization/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_7_Server_Kickstart_x86_64_7_1" for the Media.
5. Select "Kickstart default" for the Partition table.
6. Enter a password for the root user.

TODO: Looks like you can set at least some of the parameters at this point.

1. Click on the "Locations" tab.
2. Click on "Default Location" to move it to the "Selected items" control.

1. Click on the "Activation Keys tab.
2. Enter "OpenStack_Dev" for activation keys.

Click "Submit" to save your Controller Host Group.

Create the Compute Host Group:

1. Click on "New Host Group".
2. Enter "OpenStack Compute" for the Name.
3. Select "Development" for the Lifecycle Environemnt.
4. Select "OpenStack" for the Content View.
5. Click "Reset Puppet Environment to match selected Content View" next to Puppet Environment. 
6. Select the hostname for your Satellite server for the "Content Source", "Puppet CA", and "Puppet Master".

1. Click on the "Puppet Classes" tab.
2. Search for "quickstack" in the list of Available Classes.
3. Use the "+" button to add the following classes:
  * quickstack::neutron::compute

1. Click on the "Network" tab.
2. Select the Management domain (e.g. "mgt.example.com") for Domain.
3. Select "OpenStack Management" for the Subnet.
4. The Realm field can be left blank 

1. Click on the "Operating System" tab.
2. Select "x86_64" for the Architecture.
3. Select "RedHat 7.1" for the Operating system.
4. Select "Default_Organization/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_7_Server_Kickstart_x86_64_7_1" for the Media.
5. Select "Kickstart default" for the Partition table.
6. Enter a password for the root user.

TODO: Looks like you can set at least some of the parameters at this point.

1. Click on the "Locations" tab.
2. Click on "Default Location" to move it to the "Selected items" control.

1. Click on the "Activation Keys tab.
2. Enter "OpenStack_Dev" for activation keys.

Click "Submit" to save your Compute Host Group.

