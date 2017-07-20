require_relative 'provision/ansible_vagrant'

ansible_roles = []

vm_options = {
	memory: 4096
}
ansible_options = {
	playbook: "provision/playbook.yml",
	extra_args: "./user.settings.yml"
}

configure_base( "AWS", ansible_roles, vm_options, ansible_options )