# Vagrant Ansible Developer Box

This project will create a developer machine for local development with the following toolchain:
* Vagrant
* VirtualBox
* Ansible
The Basebox is a custom CentOS 7.3 64bit with Gnome.

The following items can be installed (excerpt):

* Atom IDE
* NPM
* Wowza Streaming Server
* ...


## Demo usage
https://gitlab.dwbn.org/dwbn-tools/wowza-elevator-stream-provision/

## Requirements

Required:
* Oracle Virtual Box (tested with 5.1.20)
* Vagrant (tested with 1.9.2)
* Vagrant proxyconf plugin [1]

Highly Recommended:
* Vagrant cachier plugin [2]


## Usage
1. Create a project like *my-feature-dev-provision*
2. create the following folders:
    * 01_installation
    * 02_configuration
    * 03_customization
3. Use this repository as git-subtree inside folder *01_installation*
4. Copy these files inside the root folder
    * *settings.*.yml.example*
    * *Vagrantfile.example*
    * *.gitignore*
5. Edit the settings and remove the files suffix *.example* and change values as you like 
3. Enter following command: `vagrant up`
4. Virtual Box will start and vagrant+ansible will start provisioning your system

### Setting files
The configuration is made of three files:
1. *settings.default.yml* - should only be changed by contributor of this global-provisioning (this repository)
2. *settings.project.yml* - should only be changed by contributor of project-provisioning
3. *settings.user.yml* - is optional and can be changed by every user; shall not be committed!


### Hints
* if use_proxy is set to to true, the http(s) proxies must be entered with their ip instead of their domain/host name.


=======
The first time the virtual machine is started, the provisioning might take a 
while. This means that when the virtual machine is available, the various 
components might not be immediately available. You can
check the output of the `vagrant up` command to see the status.

Log in only after the `vagrant up` command has returned to ensure everythin is ready.

The default login is *vagrant* *vagrant*. To gain root access simply type `sudo -s` in a terminal inside the vm.

Forcing a provision after the *Vagrantfile* is changed van be done by issuing the
following command:

    vagrant provision

To completely restart and provision the virtual machine, use:

    vagrant reload --provision

--------------------------------------------------------------------------------------
1. Vagrant proxyconf plugin plugin can be installed with `vagrant plugin install vagrant-proxyconf`.
2. Vagrant cachier plugin can be installed with `vagrant plugin install vagrant-cachier`.

--------------------------------------------------------------------------------------

## Known Issues
1. Updating the vbguest additions to a later version can break shared folders, due a missing symlink after the update of the additions.
As a workaround, the missing symlink can be created from the shell inside the vm: `sudo ln -s /opt/VBoxGuestAdditions-{vbox version}/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions`, where {vbox version} matches your installed virtual box version.
