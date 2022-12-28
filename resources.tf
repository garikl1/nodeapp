provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "garikl" {
  key_name   = "garik"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCFpPbbFGVx2MkYgFDvuPvASsgkYRdczx8shQoXBLpvrLCoIy5dVUnoGsEYfg/uHXTYechBA8YjZ4wcgRXMVRhzPvI4FJSw/AEqTNbmFgNheh8EROGrLBZTEcHKouEaGNqqJQ4NbUDRq3UQSE0OigB+TzSeWqo73u6XcJkmVRw+8ViqVbUgJDcNLbCXoskcfWzBRCO1moSr5+oIzmKLSr+1BZ/D0nPIZE0YDZLki3xWRZBYZwFRtLefn36nTwcxIo6KoBieF219XSG7jUg6TOv7ARKnh+djxepVcfBZiNalFITuA8Ju2qRZJTurOMGIPX7D8yJpX8xJnVBmu/5wLkrv"
}

################################################################
# Launch  Configuration
################################################################


resource "aws_launch_configuration" "nodecluster_lc" {
  name_prefix          = "ecs-launchconfig"
  image_id             = lookup(var.ecs_ami, var.aws_region)
  instance_type        = var.instance_type
  key_name             = aws_key_pair.garikl.key_name
  iam_instance_profile = aws_iam_instance_profile.ecs_ec2_role.id
  security_groups      = ["${aws_security_group.ecs_securitygroup.id}"]
  user_data            = <<EOF
  #!/bin/bash
  echo ECS_CLUSTER=nodeappcluster > /etc/ecs/ecs.config
  start ecs
  EOF
  lifecycle {
    create_before_destroy = true
  }
}

################################################################
# AutoScaling
################################################################

resource "aws_autoscaling_group" "nodecluster_asg" {
  name                 = "nodecluster-asg"
  vpc_zone_identifier  = ["${aws_subnet.main-public-1.id}", "${aws_subnet.main-public-1.id}"]
  launch_configuration = aws_launch_configuration.nodecluster_lc.name
  min_size             = 1
  max_size             = 1
  tag {
    key                 = "Name"
    value               = "ecs-ec2-contaner"
    propagate_at_launch = true
  }
}

################################################################
# IAM
################################################################

# ecs ec2 role
resource "aws_iam_role" "ecs_ec2_role" {
  name               = "ecs-ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_instance_profile" "ecs_ec2_role" {
  name = "ecs-ec2-role"
  role = aws_iam_role.ecs_ec2_role.name
}

# resource "aws_iam_role" "ecs_consul_server_role" {
#   name               = "ecs-consul-server-role"
#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "ec2.amazonaws.com"
#       },
#       "Effect": "Allow",
#       "Sid": ""
#     }
#   ]
# }
# EOF

# }

resource "aws_iam_role_policy" "ecs_ec2_role_policy" {
  name   = "ecs-ec2-role-policy"
  role   = aws_iam_role.ecs_ec2_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "ecs:CreateCluster",
              "ecs:DeregisterContainerInstance",
              "ecs:DiscoverPollEndpoint",
              "ecs:Poll",
              "ecs:RegisterContainerInstance",
              "ecs:StartTelemetrySession",
              "ecs:Submit*",
              "ecs:StartTask",
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        }
    ]
}
EOF

}

# ecs service role
resource "aws_iam_role" "ecs_service_role" {
  name               = "ecs-service-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_policy_attachment" "ecs_service_attach1" {
  name       = "ecs-service-attach1"
  roles      = [aws_iam_role.ecs_service_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

################################################################
# ECS
################################################################

resource "aws_ecs_cluster" "nodeappcluster" {
  name = "nodeappcluster"
}

#Task definition
data "template_file" "nodeapp_task_definition" {
  template = file("${var.task_definition_filename}")
  vars = {
    REPOSITORY_URL = replace("${aws_ecr_repository.app.repository_url}", "https://", "")
    APP_VERSION    = var.nodeapp_version
  }
}

resource "aws_ecs_task_definition" "nodeapp_task_definition" {
  family                = "nodeapp"
  container_definitions = data.template_file.nodeapp_task_definition.rendered
}

resource "aws_ecs_service" "nodeapp_service" {
  count           = var.nodeapp_service_enable
  name            = "nodeapp"
  cluster         = aws_ecs_cluster.nodeappcluster.id
  task_definition = aws_ecs_task_definition.nodeapp_task_definition.arn
  desired_count   = 4
  iam_role        = aws_iam_role.ecs_service_role.arn
  depends_on      = [aws_iam_policy_attachment.ecs_service_attach1]

  load_balancer {
    elb_name       = aws_elb.nodeapp_elb.name
    container_name = "nodeapp"
    container_port = 3000
  }
  #lifecycle { ignore_changes = [
  #  task_definition
  #] }
}

################################################################
# ELB
################################################################

# ELB in front of service
resource "aws_elb" "nodeapp_elb" {
  name = "nodeapp-elb"

  listener {
    instance_port     = 3000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 30
    target              = "HTTP:3000/"
    interval            = 60
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  subnets         = [aws_subnet.main-public-1.id, aws_subnet.main-public-2.id]
  security_groups = [aws_security_group.nodeapp_elb_securitygroup.id]

  tags = {
    Name = "nodeapp-elb"
  }
}


################################################################
# Security Groups
################################################################

resource "aws_security_group" "ecs_securitygroup" {
  vpc_id      = aws_vpc.main.id
  name        = "ecs"
  description = "security group for ecs"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.nodeapp_elb_securitygroup.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ecs"
  }
}

resource "aws_security_group" "nodeapp_elb_securitygroup" {
  vpc_id      = aws_vpc.main.id
  name        = "nodeapp_elb"
  description = "security group for ecs"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "nodeapp_elb"
  }
}

# jenkins
resource "aws_security_group" "jenkins-securitygroup" {
  vpc_id      = aws_vpc.main.id
  name        = "jenkins-securitygroup"
  description = "security group that allows ssh and all egress traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "jenkins-securitygroup"
  }
}