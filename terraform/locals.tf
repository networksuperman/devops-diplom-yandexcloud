locals {
  k8s = {
    region  = "ru-central1"
    version = "1.19"
    node_platform = {
      stage   = "standard-v2"
      prod    = "standard-v2"
      default = "standard-v2"
    }
    node_ssh_key   = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    instance_image = "fd8mfc6omiki5govl68h" # Ubuntu-20.04
    instance_count_map = {
      stage   = "3"
      prod    = "6"
      default = "3"
    }
    instance_memory_map = {
      stage   = "2"
      prod    = "4"
      default = "2"
    }
    instance_cores_map = {
      stage   = "2"
      prod    = "4"
      default = "2"
    }
    instance_core_fraction_map = {
      stage   = "20"
      prod    = "100"
      default = "20"
    }
    subnet_ids = {
       for k, v in yandex_vpc_subnet.subnet : v.zone => v.id 
    }
    subnet_id = {
       for k, v in yandex_vpc_subnet.subnet : v.zone => v.id 
    }

  }
  
}