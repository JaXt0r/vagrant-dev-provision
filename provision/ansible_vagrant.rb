# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'fileutils'
require 'uri'


def configure_base( vm_machine_name, vm_options = {}, ansible_options = {}, &block )

  machine_options = {
		memory: 4096
	}.merge(vm_options)

  # parse configuration from user.settings.yml  
  settings_file = 'user.settings.yml'
  local_settings =  File.exists?( settings_file) ? YAML::load_file( settings_file ) : {}
  
  box_settings = local_settings.has_key?('box') ? local_settings['box'] : {}
  user_settings = local_settings.has_key?('user') ? local_settings['user'] : {}
  general_settings = local_settings.has_key?('settings') ? local_settings['settings'] : {}
  system_settings = general_settings.has_key?('system') ? general_settings['system'] : {}
  
  workstation_config = {
	distro: ENV['DISTRO'] || box_settings['distro'] || 'coreos73-desktop',
	DE: ENV['DESKTOP_ENVIRONMENT'] || box_settings['desktop_environment'] || 'gnome'
  }
  
  if user_settings.has_key?('fullname')
	user_name_parts = user_settings['fullname'].split
	user_data = {
		fullname: user_settings['fullname'],
		firstname: user_settings['first_name'] || user_name_parts.first.downcase,
		lastname: user_settings['last_name'] || user_name_parts.last.downcase,
		groupname: 'developers',
		email: user_settings['email'] || "#{user_settings['fullname'].gsub(/\s/,'.').downcase}@example.com"
	}
  else
	user_data = {
		fullname: 'developer',
		firstname: 'vagrant',
		groupname: 'vagrant',
		email: '',
		username: 'vagrant',
	}
  end
  
  # print user configuration
  p user_data
  
  #configure vm
  puts "Work station conguration: #{workstation_config.inspect}"

	Vagrant.configure("2") do |config|


		## disable auto update of VirtualBox guest addons, to prevent breakage of "shared folders" on update
		## the combination of the used OS and the later vbguest addons might lead to breakage of the shared folder function.
		if Vagrant.has_plugin?("vagrant-vbguest")
			config.vbguest.auto_update = false
		end
	
		if Vagrant.has_plugin?("vagrant-proxyconf")
	 		if system_settings['use_proxy']
				if system_settings.has_key?('http_proxy')
					config.proxy.http = "http://#{system_settings['http_proxy']}"
				end
				if system_settings.has_key?('https_proxy')
					config.proxy.https = "http://#{system_settings['https_proxy']}"
				end
				if system_settings.has_key?('no_proxy')
					config.proxy.no_proxy = "#{system_settings['no_proxy']}"
				end
			end
		end

		## set ansible provisioner
		## windows: ansible_local (sets up ansible in vm guest)
		## others: require an ansible installation on the host machine
		ansible_version = Vagrant::Util::Platform.windows? ? :ansible_local : :ansible


    config.vm.provision ansible_version, run: "always" do |ansible|

      if ansible_options.key?(:tags)
        ansible.tags = ansible_options[:tags]
      end


      if ansible_options.key?(:playbook)
				ansible.playbook = ansible_options[:playbook]
			else
				ansible.playbook = "provision/playbook.yml"
			end

			ansible.verbose        = true
			ansible.install        = true
			ansible.limit          = "all"
			if ansible_options.key?(:extra_vars)
				ansible.extra_vars       = ansible_options[:extra_vars]
			else
				ansible.extra_vars     = "./user.settings.yml"
			end
		end


		#fix:  “Warning: Unprotected Private Key File, this private key will be ignored.”
		config.vm.synced_folder ".", "/vagrant", :owner=> 'vagrant', :group=>'vagrant', :mount_options => ['dmode=700', 'fmode=600'], type: "virtualbox"


		config.vm.box = box_settings['distro']
		config.vm.box_url =  box_settings['url']
		config.vm.hostname =  box_settings['hostname']
		config.vm.boot_timeout = 360 # slightly increased to prevent numerous timeout messages

		config.ssh.forward_agent = true
		config.ssh.forward_x11 = true
		config.ssh.insert_key = true

		### add caching mapping to vm
		if Vagrant.has_plugin?("vagrant-cachier")
		  config.cache.scope = :machine
		  config.cache.enable :yum
		  config.cache.enable :npm
		  config.cache.enable :generic, {
			  "wget" => { cache_dir: "/var/cache/wget" }
		  }
		end
	
		## customize vm configuration
	    config.vm.provider :virtualbox do |vb|
		  vb.gui = true
		  vb.name = "#{vm_machine_name} - #{workstation_config[:distro].capitalize} with #{workstation_config[:DE].upcase}"
		  vb.customize ["modifyvm", :id, "--graphicscontroller", "vboxvga"]
		  vb.customize ["modifyvm", :id, "--accelerate3d", "on"]
		  vb.customize ["modifyvm", :id, "--ioapic", "on"]
		  vb.customize ["modifyvm", :id, "--vram", "128"]
		  vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
		  vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
		  vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
		  vb.customize ["modifyvm", :id, "--groups", "/develop/#{vm_machine_name}"]
		  vb.customize ["modifyvm", :id, "--chipset", "ich9" ]
		  vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]

		  if box_settings.has_key?('memory')
			vb.customize ["modifyvm", :id, "--memory", "#{box_settings['memory']}"]
		  else
			vb.customize ["modifyvm", :id, "--memory", "#{machine_options[:memory]}"]
		  end

		  if box_settings.has_key?('cpus')
			 vb.customize ["modifyvm", :id, "--cpus", "#{box_settings['cpus']}"]
		  else
			vb.customize ["modifyvm", :id, "--cpus", "2"]
		  end

		  if box_settings.has_key?('monitorcount')
			 vb.customize ["modifyvm", :id, "--monitorcount", "#{box_settings['monitorcount']}"]
		  end

		  if box_settings.has_key?('paravirtprovider')
			 vb.customize ["modifyvm", :id, "--paravirtprovider", "#{box_settings['paravirtprovider']}"]
		  end

		  if !user_settings.has_key?('usb2')
				# Disable USB
				vb.customize ["modifyvm", :id, "--usb", "off"]
				vb.customize ["modifyvm", :id, "--usbehci", "off"]
		  end
		  
		end 
		
		## add share mapping to vm
		if box_settings.has_key?('shares')
			shares = box_settings['shares'] 
			shares.each do |key,share|
				if share.has_key?('host') && share.has_key?('guest') 
					config.vm.synced_folder share["host"], share["guest"], type: "virtualbox"
				end
			end
		end

		## add port forwarding to vm
		if box_settings.has_key?('portforwardings')
			portforwardings = box_settings['portforwardings'] 
			portforwardings.each do |name,details|
				if  details.has_key?('host-port') && details.has_key?('guest-port') 
					if details.has_key?('protocol')
						config.vm.network "forwarded_port", name: name, guest: details["guest-port"], host: details["host-port"], protocol: details["protocol"]
					else
						config.vm.network "forwarded_port", name: name, guest: details["guest-port"], host: details["host-port"]
					end
				end
			end
		end
		
	end
end