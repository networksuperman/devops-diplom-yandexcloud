resource "yandex_compute_instance" "k8s-control-plane" {

  name                      = "control-plane"
  platform_id               = local.k8s.node_platform[terraform.workspace]
  allow_stopping_for_update = true
  zone                      = "ru-central1-a"

  resources {
    memory        = local.k8s.instance_memory_map[terraform.workspace]
    cores         = local.k8s.instance_cores_map[terraform.workspace]
    core_fraction = local.k8s.instance_core_fraction_map[terraform.workspace]
  }


  boot_disk {
    initialize_params {
      image_id = local.k8s.instance_image
      size     = 50
    }
  }

  network_interface {
    subnet_id = lookup(local.k8s.subnet_ids, "ru-central1-a")
    nat       = true
  }

      metadata = {
        ssh-keys = local.k8s.node_ssh_key
      }

}