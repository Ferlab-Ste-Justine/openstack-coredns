# Deprecation notice

This module is getting deprecated in favor of the following modules:
- https://github.com/Ferlab-Ste-Justine/terraform-openstack-coredns-security-groups
- https://github.com/Ferlab-Ste-Justine/terraform-openstack-coredns-server

While less concice, the above modules provide needed flexibility when operating a coredns cluster by allowing us to reprovision individual nodes and by decoupling the networking from the vms.

Also, the new module stores zonefiles in etcd instead of Ceph which is more consistent with how our coredns servers are managed across projects.

This module will be updated as needed while legacy clusters are still using it, but it will eventually be archived.

# About

This module provision coredns instances on Openstack.

The server is configured to to work with zonefiles which are fetched from an Openstack object store container.

The server will automatically detect any changes in the containers' objects (additions, deletions and updates) and update its zonefiles accordingly.

# Note About Built-in Alternative

Openstack does optionally support DNS as a service. 

If it is installed in your Openstack, made accessible to you and it suits your needs, you may find it simpler to rely on that. 

But if you don't have access to it, than this module is an alternative.

# Limitations

## Expected Network Ports Argument

Because the ip of dns servers need to be stable (for internal dns servers, their ips cannot be encapsulated under names as they are the resolvers of those names), the module expects network ports to be defined outside of the module and passed as an argument. 

This helps fixate the ips of dns server even in the event that they need to be reprovisioned.

## Expected Zonefile Naming Convention

The server expects a strict naming convention for the objects containing a zonefile: The name of the object a suffix of the domain the zonefile is for.

See the following project for an implementation that fulfills this requirement: https://github.com/Ferlab-Ste-Justine/openstack-zonefile

## Object Protocol Support

Currently, the zonefile scrapping only works with containers that are accessible using the Swift protocol (which usually shouldn't be a problem for most Openstack installations).

# Usage

## Input

- namespace: Namespace string to prepend generated resource names with. Defaults to nothing.

- image_id: ID of the image to provision the servers with. The module has been validated with Ubuntu.

- flavor_id: ID of the vm flavor used to provision the servers.

- network_ports: Array of network ports to associate with the vms. They should be of type **openstack_networking_port_v2**. The number of ports that are passed will dictate the number of servers that will be provisioned.
- keypair_name: The ssh keypair that can be used to ssh into the servers.
- container_info: The object store container that the servers will query for zonefiles. It is a map that should contain the following keys:
  - name: Name of the container
  - auth_url: Keystone auth url that the servers will use to access the container
  - application_id: Id of the Openstack application that the servers will use to access the container
  - application_secret: Authentication secret of the Openstack application that the servers will use to access the container

## Output

- node_ids: Ids of the provisioned dns servers

## Example

```
resource "openstack_objectstorage_container_v1" "dns" {
  name   = "dns"
  content_type = "text/plain"
  container_read = "${var.tenant_id}:${var.object_store_reader_credential_id}"
}

resource "openstack_networking_port_v2" "coredns" {
  count          = 3
  name           = "coredns-${count.index + 1}"
  network_id     = module.reference_infra.networks.internal.id
  security_group_ids = [module.reference_infra.security_groups.default.id]
  admin_state_up = true
}

module "dns_servers" {
  source = "git::https://github.com/Ferlab-Ste-Justine/openstack-coredns.git"
  image_id = module.ubuntu_bionic_image.id
  flavor_id = module.reference_infra.flavors.nano.id
  network_ports = openstack_networking_port_v2.coredns
  keypair_name = openstack_compute_keypair_v2.bastion_internal_keypair.name
  container_info = {
    name = openstack_objectstorage_container_v1.dns.name
    os_auth_url = var.auth_url
    os_region_name = var.region
    os_app_id = var.object_store_reader_credential_id
    os_app_secret = var.object_store_reader_credential_secret
  }
}

module "external_domain" {
  source = "git::https://github.com/Ferlab-Ste-Justine/openstack-zonefile.git"
  domain = "mydomain.com"
  container = openstack_objectstorage_container_v1.dns.name
  a_records = [
    {
      prefix = "qa"
      ip = openstack_networking_floatingip_v2.edge_reverse_proxy_floating_ip.address
    }
  ]
}
```