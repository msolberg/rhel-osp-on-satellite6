# Managing Red Hat Enterprise Linux OpenStack Platform with Red Hat Satellite

## Introduction

This document serves as a guide on how to deploy and manage RHEL-OSP
with Red Hat Satellite.

## Document Conventions

This guide will present each step with instructions for both the
Graphical User interface and the Command Line interface where
possible.

## Satellite 6 Installation

Install Satellite 6 as per the [Satellite 6 Installation Guide (https://access.redhat.com/documentation/en-US/Red_Hat_Satellite/6.0/html/Installation_Guide/index.html)].

## Preparing Content for OpenStack Deployment

### Create Lifecycle Environments

In the Foreman UI, use the following steps to create two lifecycle environments for our OpenStack deployments.

1. Navigate to Content > Lifecycle Environments
2. Click “+” Beside the "Library" environment
3. Enter “Development” for the name.
4. Click submit
5. Click the “+” next to Development
6. Enter “Production” for the name.
7. Click submit.

Or from the commandline:

```
hammer lifecycle-environment create --organization='Default Organization' --name=Devel --
prior=Library
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

From the cli:

```
hammer subscription upload file=/path/to/manifest.zip
```

### Enable Content from Red Hat Network

The following steps will sync the required software from the Red Hat
Network to your Red Hat Satellite.

1. Navigate to Content > Repositories > Red Hat Repositories.
2. Expand the “Red Hat Enterprise Linux Server” Product.
3. Select the “Red Hat Enterprise Linux 7 Server (RPMs)” repository set underneath the product. (This may take a few moments).
4. Select the "Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server" repository.
5. Select the "RHN Tools for Red Hat Enterprise Linux" Product.
6. Select the "RHN Tools for Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server" repository.
7. Select the "Red Hat OpenStack" Product.
8. Select the "Red Hat OpenStack 6.0 for RHEL 7 RPMs x86_64 7Server" repository.

In order to kickstart systems from the Satellite server, a kickstart tree needs to be synced. On the same page:

1. Select the “Red Hat Enterprise Linux 7 Server (Kickstart)” repository set unerneath the same product as above.
2. Select the desired kickstart tree “Red Hat Enterprise Linux 7 Server Kickstart x86_64 7.1"

To perform the same actions from the command line:

```
```

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

### Import the Quickstack Puppet module

Use the following steps to download and install the Quickstack puppet module:

First we need to create a Product for our Puppet modules:

Navigate to Content > Products > New Product

Then add a new product:

1. For name, enter 'OpenStack Configuration'
2. Click Save

From the cli:

```
hammer product create --organization='Default Organization' --name="OpenStack Configuration"
```

Next create a repository to house the puppet modules:

Navigate to Content > Products > Click on the “Custom Configuration” product. Click “Create Repository” on the left.

And then add a custom repository:

1. Click 'New Repository' in the upper right hand corner.
2. For name, enter 'Puppet Modules'
3. Select 'puppet' for Type
5. Click save.

From the CLI:

```
hammer repository create --organization='Default Organization' --product='OpenStack Configuration' --name='Puppet Modules' --content-type=puppet
```

Next, import the quickstack puppet module from github.

Use the `pulp-puppet-module-builder` utility from the CLI to create an uploadable format from the git repository:

```
# mkdir /modules
# pulp-puppet-module-builder --output-dir=/modules --url=https://github.com/msolberg/astapor/ -p astapor/puppet/modules/quickstack --branch=satellite6_compat
```

Then, upload the resulting module to the OpenStack Configuration product.

```
# hammer repository upload-content --name='Puppet Modules'  --path=/modules/redhat-quickstack-3.0.24.tar.gz --organization='Default Organization' --product='OpenStack Configuration'
```

*Note:  We also need to get the openstack-puppet-modules modules in there.  Here's how I did it:*

```
rpm -ivh /var/lib/pulp/published/yum/master/yum_distributor/Default_Organization-Red_Hat_OpenStack-Red_Hat_OpenStack_6_0_for_RHEL_7_RPMs_x86_64_7Server/*/openstack-puppet-modules-2014.2.15-3.el7ost.noarch.rpm
mkdir /openstack-modules
cd /usr/share/openstack-puppet/modules
pulp-puppet-module-builder --output-dir=/openstack-modules
cd /openstack-modules
hammer repository upload-content --name='Puppet Modules' --organization='Default Organization' --product='OpenStack Configuration' --path .
```

The following are missing metadata:

common
nagios
puppet
sysctl
vlan

We'll need to create metadata for them so that they can be uploaded to Satellite.


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
4. Add the following repositories to the Content View:
  * Red Hat Enterprise Linux 7 Server Kickstart x86_64 7.1
  * Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server
  * Red Hat OpenStack 6.0 for RHEL 7 RPMs x86_64 7Server
  * RHN Tools for Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server

Add the Quickstack puppet module to the content view:

1. Click the “Puppet Modules" tab.
2. Click "Add New Module".
3. Click "Select a Version" next to the module named "quickstack".
4. Select the "Use Latest" version.

Publish the version of the content view:

1. Click "Publish New Version"
2. Optionally enter a comment in the description field.
3. Click "Publish"



