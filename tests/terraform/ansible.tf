locals {
  yaml_file = templatefile("${path.module}/inventory_template.tmpl",
    {
      ip_address   = "${aws_instance.test_machine.public_ip}"
      control_user = "${var.control_username}"
    }
  )
}

resource "local_file" "ansible_inventory" {
  filename = "../inventory.yml"
  content  = local.yaml_file
}