resource "aws_instance" "jenkins-instance" {
  ami           = var.ami[var.aws_region]
  instance_type = "t2.small"

  # the VPC subnet
  subnet_id = aws_subnet.main-public-1.id

  # the security group
  vpc_security_group_ids = [aws_security_group.jenkins-securitygroup.id]

  # the public SSH key
  key_name = aws_key_pair.garikl.key_name

  # user data
  user_data = data.cloudinit_config.cloudinit-jenkins.rendered
}

resource "aws_ebs_volume" "jenkins-data" {
  availability_zone = "us-east-2a"
  size              = 8
  type              = "gp2"
  tags = {
    Name = "jenkins-data"
  }
}

resource "aws_volume_attachment" "jenkins-data-attachment" {
  device_name = var.instance_device_name
  volume_id   = aws_ebs_volume.jenkins-data.id
  instance_id = aws_instance.jenkins-instance.id
}