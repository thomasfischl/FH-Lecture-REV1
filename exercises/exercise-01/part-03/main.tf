###########################################
# provider
###########################################

provider "aws" {
  region = "us-east-1"
}

provider "local" {
}

provider "tls" {
}

###########################################
# locals
###########################################

locals {
  webserver_ami           = "ami-0b5eea76982371e91"
  webserver_instance_type = "t2.micro"
  webserver_key_name      = "webserver-key-pair"
}

###########################################
# data
###########################################

data "aws_iam_instance_profile" "webserver_instance_profile" {
  name = "LabInstanceProfile"
}

###########################################
# resources
###########################################

resource "aws_s3_bucket" "webserver_www_root" {
  bucket_prefix = "webserver-www-"
}

resource "aws_s3_bucket_acl" "webserver_www_root_acl" {
  bucket = aws_s3_bucket.webserver_www_root.id
  acl    = "private"
}

resource "aws_s3_object" "webserver_www_files" {
  for_each = fileset("www/", "*")
  bucket   = aws_s3_bucket.webserver_www_root.id
  key      = each.value
  source   = "www/${each.value}"
  etag     = filemd5("www/${each.value}")
}


resource "aws_security_group" "webserver_sg" {
  name = "webserver-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "webserver_key_pair" {
  key_name   = local.webserver_key_name
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "webserver_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = local.webserver_key_name
}




resource "aws_instance" "webserver_instance" {
  depends_on = [
    aws_key_pair.webserver_key_pair
  ]

  ami                    = local.webserver_ami
  instance_type          = local.webserver_instance_type
  vpc_security_group_ids = ["${aws_security_group.webserver_sg.id}"]

  key_name = aws_key_pair.webserver_key_pair.key_name

  iam_instance_profile = data.aws_iam_instance_profile.webserver_instance_profile.name

  user_data = <<-EOF
            #!/bin/bash

            echo "start installing webserver"
            sudo yum update -y
            sudo yum install -y httpd
            sudo systemctl start httpd
            sudo systemctl enable httpd
            usermod -a -G apache ec2-user
            
            echo "download http root files"
            sudo rm -rf /var/www/html/*
            sudo aws s3 sync s3://${aws_s3_bucket.webserver_www_root.id} /var/www/html
            sudo chmod 644 /var/www/html/*

            echo "install successful"
          EOF

  tags = {
    Name = "webserver"
  }
}

###########################################
# output 
###########################################

output "public_ip" {
  value = aws_instance.webserver_instance.public_ip
}

output "url" {
  value = "http://${aws_instance.webserver_instance.public_ip}"
}

output "ssh-command" {
  value = "sudo ssh ec2-user@${aws_instance.webserver_instance.public_ip} -i ${aws_key_pair.webserver_key_pair.key_name}"
}

output "bucket" {
  value = aws_s3_bucket.webserver_www_root.id
}
