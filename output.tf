output node_ids {
  value = [for vm in openstack_compute_instance_v2.coredns: vm.id]
}