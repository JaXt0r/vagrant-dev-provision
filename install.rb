# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'fileutils'
require 'uri'
require './01_installation/plugins_vagrant/vagrant-provision-reboot-plugin'



def install( &block )

  install_plugins()


  # parse configurations from threee setting's.yml
  default_settings  = YAML::load_file( '01_installation/settings.default.yml' )
  project_settings  = YAML::load_file( './settings.project.yml' )
  user_settings     = YAML::load_file( './settings.user.yml' )


  full_settings     =  default_settings.deep_merge(project_settings).deep_merge(user_settings);
  
  puts "used settings (combination of default-/project-/user-settings):"
  puts full_settings.to_yaml
  puts "---"

  validate_schema(full_settings)


  # Convenient shortcuts
  box_settings      = full_settings['box']
  user_settings     = full_settings['user']
  ansible_settings  = full_settings['ansible']
  general_settings  = full_settings['settings']
  system_settings   = general_settings['system']


  Vagrant.configure("2") do |config|
    ## disable auto update of VirtualBox guest addons, to prevent breakage of "shared folders" on update
    ## the combination of the used OS and the later vbguest addons might lead to breakage of the shared folder function.
    config.vbguest.auto_update = false


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

    ## set ansible provisioner
    ## windows: ansible_local (sets up ansible in vm guest)
    ## others: require an ansible installation on the host machine
    ansible_type = Vagrant::Util::Platform.windows? ? :ansible_local : :ansible
    config.vm.provision ansible_type, run: "always" do |ansible|

      ansible.tags = ansible_settings["roles"]


      ansible.playbook = "01_installation/playbook.yml"

      ansible.verbose        = true
      ansible.install        = true
      ansible.limit          = "all"
      ansible.extra_vars     = full_settings
    end
    
    # Reboot after provisioning
    # Needed to have Desktop settings applied
    config.vm.provision :unix_reboot


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
    config.cache.scope = :machine
    config.cache.enable :yum
    config.cache.enable :npm
    config.cache.enable :generic, {
      "wget" => { cache_dir: "/var/cache/wget" }
    }


    ## customize vm configuration
      config.vm.provider :virtualbox do |vb|
      vb.gui = true
      vb.name = "#{box_settings["name"]} - #{box_settings['distro'].gsub("/","-")} with #{box_settings['desktop_environment']}"
      vb.customize ["modifyvm", :id, "--graphicscontroller", "vboxvga"]
      vb.customize ["modifyvm", :id, "--accelerate3d", "on"]
      vb.customize ["modifyvm", :id, "--ioapic", "on"]
      vb.customize ["modifyvm", :id, "--vram", "128"]
      vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
      vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
      vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
      vb.customize ["modifyvm", :id, "--groups", "/develop/#{box_settings["name"]}"]
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
      box_settings['shares'].each do |share|
        config.vm.synced_folder share["host"], share["guest"], type: "virtualbox"
      end
    end

    ## add port forwarding to vm
    if box_settings.has_key?('portforwardings')
      box_settings['portforwardings'].each do |details|
        if details.has_key?('protocol')
          config.vm.network "forwarded_port", name: details['name'], guest: details["guest_port"], host: details["host_port"], protocol: details["protocol"]
        else
          config.vm.network "forwarded_port", name: details['name'], guest: details["guest_port"], host: details["host_port"]
        end
      end
    end


  end
end



def install_plugins()
  required_plugins = %w(vagrant-vbguest vagrant-cachier kwalify)

  plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
  if not plugins_to_install.empty?
    puts "Installing plugins: #{plugins_to_install.join(' ')}"
    if system "vagrant plugin install #{plugins_to_install.join(' ')}"
      exec "vagrant #{ARGV.join(' ')}"
    else
      abort "Installation of one or more plugins has failed. Aborting."
    end
  end
end



def validate_schema( config )
  puts "### Validate yaml against schema."


  schema = YAML.load_file('01_installation/settings.schema.yml')
  validator = Kwalify::Validator.new(schema)
  errors = validator.validate(config)
  
  if errors && !errors.empty?
    puts "Schema errors:"
    puts errors
    raise 'There are schema errors. Fix them before going on.'
  end
end



# Needed for right merging of config-values
# @see https://stackoverflow.com/a/9381776/3680249
class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
        self.merge(second, &merger)
    end
end



private :install_plugins, :validate_schema