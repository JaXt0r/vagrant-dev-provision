**Ansible Eclipse AWS Developer Box**

This project will create a developer machine for AWS Lambda development, aimed for Lambas implemented in Java.
The Basebox is a custom CentOS 7.3 64bit with Gnome.

The following items will be installed:

* **JDK 8** under */opt/sw/java*
* **Apache Maven 3.3.50** under */opt/sw/maven*, including a settings.xml under *~/.m2/conf/*
* **Eclipse Neon J2EE** under */opt/sw/eclipse-neon*, including the AWS and m2e add-ons pre-installed
* **Android Studio** under */opt/sw/android-studio*, ready to install required addons
* **Oracle SQL Developer 4.2**
* **Serverless Framwork**
* **AWS Cli** 
* **Docker CE** 

**Requirements**

Required:
* Oracle Virtual Box (tested with 5.1.20)
* Vagrant (tested with 1.9.2) 
* Vagrant proxyconf plugin [1]

Highly Recommended:
* Vagrant cachier plugin[2]


**Usage**
1. Check out project
2. Copy the file *user.settings.yml.example* to *user.settings.yml* and edit the file for your needs
3. Enter following command: `vagrant up`
4. Virtual Box will start after a while

As of now not all configuration parameters of the user.settings.yml file are actually used.
The settings under `user` are not yet in use.

if use_proxy is set to to true, the http(s) proxies must be entered with their ip instead of their domain/host name.

=======
The first time the virtual machine is started, the provisioning might take a 
while. This means that when the virtual machine is available, the various 
components (Java, Eclipse, etc.) might not be immediately available. You can
check the output of the `vagrant up` command to see the status.

Log in only after the `vagrant up` command has returned to ensure everythin is ready.

The default user is vagrant, the dafault password is vagrant. To gain root access simply type `sudo -s` in a terminal inside the vm.

Forcing a provision after the *Vagrantfile* is changed van be done by issuing the
following command:

    vagrant provision

To completely restart and provision the virtual machine, use:

    vagrant reload --provision

--------------------------------------------------------------------------------------
1. Vagrant proxyconf plugin plugin can be installed with `vagrant plugin install vagrant-proxyconf`.
2. Vagrant cachier plugin can be installed with `vagrant plugin install vagrant-cachier`.

--------------------------------------------------------------------------------------
**Known Issues**
1. Updating the vbguest addtions to a later version can break shared folders, due a missing symlink after the update of the additions.
As a workaround, the missing symlink can be created from the shell inside the vm: `sudo ln -s /opt/VBoxGuestAdditions-{vbox version}/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions`, where {vbox version} matches your installed virtual box version.
