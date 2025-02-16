resource "docker_image" "test_server" {
  name = "takeyamajp/ubuntu-sshd:latest"
}

resource "docker_container" "test_server" {
  name  = "test_server"
  image = docker_image.test_server.image_id

  ports {
    internal = "22"
    external = var.ansible_port
  }

  env = ["ROOT_PASSWORD=${var.ansible_password}"]
}