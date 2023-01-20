###########################################
# provider
###########################################

provider "aws" {
  region = "us-east-1"
}

###########################################
# locals
###########################################

locals {
  webserver_ami           = "ami-0b5eea76982371e91"
  webserver_instance_type = "t2.micro"
}

###########################################
# resources
###########################################

resource "aws_security_group" "webserer_sg" {
  name = "webserver-sg"

  ingress {
    from_port   = 80
    to_port     = 80
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


resource "aws_instance" "webserver_instance" {
  ami                    = local.webserver_ami
  instance_type          = local.webserver_instance_type
  vpc_security_group_ids = ["${aws_security_group.webserer_sg.id}"]

  user_data = <<-EOF
            #!/bin/bash
            sudo yum update -y
            sudo yum install -y httpd
            sudo systemctl start httpd
            sudo systemctl enable httpd
            usermod -a -G apache ec2-user
            echo "<html><body><h1>Hello World from $(hostname -f)</h1></body></html>" > /var/www/html/index.html
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