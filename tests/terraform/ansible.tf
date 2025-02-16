locals {
  yaml_file = templatefile("${path.module}/inventory_template.tmpl",
    {
      ansible_host     = "${var.ansible_host}"
      ansible_port     = "${var.ansible_port}"
      ansible_username = "${var.ansible_username}"
      ansible_password = "${var.ansible_password}"
    }
  )
}

resource "local_file" "ansible_inventory" {
  filename = "../inventory.yml"
  content  = local.yaml_file
}