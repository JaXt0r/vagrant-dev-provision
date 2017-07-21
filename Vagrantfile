require_relative 'provision/ansible_vagrant'


ansible_tags = []


vm_options = {
	memory: 4096
}
ansible_options = {
	playbook: "provision/playbook.yml",
#  tags: ansible_tags, # If uncommented there the existing roles will be used when tagged with these values.
	extra_args: "./user.settings.yml"
}


configure_base( "AWS", ansible_roles, vm_options, ansible_options )