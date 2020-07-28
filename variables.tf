variable "namespace" {
  description = "Namespace to create the resources under"
  type = string
  default = ""
}

variable "image_id" {
    description = "ID of the vm image used to provision the nodes"
    type = string
}

variable "flavor_id" {
  description = "ID of the VM flavor for the nodes"
  type = string
}

variable "network_ports" {
  description = "List of network ports to assign to the nodes. Should be of type openstack_networking_port_v2. The length of the list will dictate the number of provisioned nodes."
  type = list(any)
}

variable "keypair_name" {
  description = "Name of the keypair that will be used to ssh on the replicas"
  type = string
}

variable "container_info" {
  description = "Connection info to access the swift container. Should contain the following keys: name, auth_url, application_id, application_secret"
  type = map(string)
}