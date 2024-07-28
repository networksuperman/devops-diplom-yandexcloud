output "external_ip_control_plane" {
  value = yandex_compute_instance.k8s-control-plane.network_interface.0.nat_ip_address
}

output "external_ip_nodes" {
  value = yandex_compute_instance_group.k8s-node-group.instances[*].network_interface[0].nat_ip_address
}