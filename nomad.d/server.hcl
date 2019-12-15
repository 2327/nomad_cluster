server {
  enabled = true
  bootstrap_expect = 3
}

consul {
  address             = "127.0.0.1:8500"
  server_service_name = "nomad"
  client_service_name = "nomad-client"
  auto_advertise      = true
  server_auto_join    = true
  client_auto_join    = true
}

bind_addr = "0.0.0.0"

advertise {
  http = "192.168.88.27"
  rpc = "192.168.88.27:4647"
}

client {
  enabled = true

  host_volume "hw" {
    path      = "/mnt/storage/hw"
    read_only = false
  }

}

