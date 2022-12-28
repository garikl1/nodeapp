variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "ecs_ami" {
  type = map(string)
  default = {
    us-east-2 = "ami-0693a7971cd761811"
    us-east-1 = "ami-03f8a7b55051ae0d4"
  }
}

variable "ami" {
  type = map(string)
  default = {
    us-east-2 = "ami-02f3416038bdb17fb"
  }
}

variable "task_definition_filename" {
  type    = string
  default = "nodeapp.json.tpl"
}

variable "nodeapp_service_enable" {
  type    = number
  default = 1
}

variable "nodeapp_version" {
  type    = string
  default = "0"
}

variable "instance_device_name" {
  default = "/dev/xvdh"
}

variable "jenkins_version" {
  default = "2.319.2"
}
