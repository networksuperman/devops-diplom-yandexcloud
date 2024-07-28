resource "yandex_vpc_network" "network" {
  name = "network"
}

resource "yandex_vpc_subnet" "subnet" {
  for_each = {
    for k,v in var.subnets :
      v.zone => v
  }
  name           = "subnet-${each.value.zone}"
  zone           = "${each.value.zone}"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["${each.value.cidr}"]
}