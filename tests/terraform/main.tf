resource "docker_image" "test_server" {
  name = "test_server_ubuntu"
  build {
    context = "."
    tag     = ["test_server:ubuntu"]
  }
}

resource "docker_container" "test_server" {
  name  = "test_server"
  image = docker_image.test_server.image_id
  privileged = true

  volumes {
    container_path = "/sys/fs/cgroup"
    host_path      = "/sys/fs/cgroup"
    read_only      = true
  }
  ports {
    internal = "22"
    external = var.ansible_port
  }

  env = ["ROOT_PASSWORD=${var.ansible_password}"]
}