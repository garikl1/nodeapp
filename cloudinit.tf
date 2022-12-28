data "cloudinit_config" "cloudinit-jenkins" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content = templatefile("scripts/jenkins-init.sh", {
      DEVICE          = var.instance_device_name
      JENKINS_VERSION = var.jenkins_version
    })
  }
}

