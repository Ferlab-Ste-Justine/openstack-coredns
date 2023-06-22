data "template_cloudinit_config" "coredns_config" {
  count     = length(var.network_ports)
  gzip = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = templatefile(
      "${path.module}/files/cloud_config.yaml.tpl", 
      {
        corefile = templatefile(
          "${path.module}/files/Corefile.tpl",
          {
            hostname = var.namespace != "" ? "coredns-${var.namespace}-${count.index + 1}" : "coredns-${count.index + 1}"
            bind_address = var.network_ports[count.index].all_fixed_ips.0
          }
        )
        zonefiles_refresher = file("${path.module}/files/zonefile_refresher.py")
        zonefiles_container = var.container_info.name
        openstack_auth_url = var.container_info.os_auth_url
        openstack_region_name = var.container_info.os_region_name
        openstack_application_id = var.container_info.os_app_id
        openstack_application_secret = var.container_info.os_app_secret
        coredns_version = "1.7.0"
      }
    )
  }
}

resource "openstack_compute_instance_v2" "coredns" {
  count     = length(var.network_ports)
  name      = var.namespace != "" ? "coredns-${count.index + 1}-${var.namespace}" : "coredns-${count.index + 1}"
  image_id  = var.image_id
  flavor_id = var.flavor_id
  key_pair  = var.keypair_name
  user_data = data.template_cloudinit_config.coredns_config[count.index].rendered

  network {
    port = var.network_ports[count.index].id
  }

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}