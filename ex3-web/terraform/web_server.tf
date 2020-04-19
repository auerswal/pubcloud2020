# Terraform configuration for an AWS Virtual Private Cloud (VPC).
# Copyright (C) 2020  Erik Auerswald <auerswal@unix-ag.uni-kl.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# providers - AWS in this case, region from AWS CLI is ignored
provider "aws" {
  version = "~> 2.52"
  profile = "default"
  region  = "eu-central-1"
}

### variables - select AMI flavor
variable "ami_owner" {}
variable "ami_name" {}

### data sources

# AMI ID for web server
data "aws_ami" "gnu_linux_image" {
  owners      = [var.ami_owner]
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# default VPC
data "aws_vpc" "default" {
  default = true
}

### resources

# public SSH key for remote access to EC2 instance
resource "aws_key_pair" "course_ssh_key" {
  key_name   = "tf-pubcloud2020"
  public_key = file("../../../pubcloud2020_rsa_id.pub")
}

# S3 bucket
resource "aws_s3_bucket" "s3_image" {
  bucket = "pubcloud2020-ex3-website-auerswal"
  acl    = "public-read"
  policy = file("s3-access-policy.json")

  website {
    index_document = "index.html"
  }

  tags = {
    Name = "S3_bucket_for_image"
  }
}

# disable S3 Public Access Block - once per AWS account
resource "aws_s3_account_public_access_block" "s3_pab" {}

# image file in S3 bucket
resource "aws_s3_bucket_object" "image" {
  bucket       = aws_s3_bucket.s3_image.id
  key          = "image.png"
  source       = "../s3/image.png"
  content_type = "image/png"
  acl          = "public-read"
  etag         = filemd5("../s3/image.png")
}

# index document for S3 static website
resource "aws_s3_bucket_object" "index" {
  bucket       = aws_s3_bucket.s3_image.id
  key          = "index.html"
  source       = "../s3/index.html"
  content_type = "text/html"
  acl          = "public-read"
  etag         = filemd5("../s3/index.html")
}

# Security Group
resource "aws_security_group" "sg_web" {
  name        = "tf-sg-web"
  description = "Allow HTTP(S) and SSH access to web server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    self        = true
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Allow everything inside the SG"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from the Internet"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from the Internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from the Internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Internet access for, e.g., updates"
  }

  tags = {
    Name = "Web_Server_Security_Group"
  }
}

# web server EC2 instance
resource "aws_instance" "ec2_web" {
  depends_on = [aws_s3_bucket.s3_image,
    aws_s3_bucket_object.image,
  aws_s3_bucket_object.index]
  ami                         = data.aws_ami.gnu_linux_image.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.course_ssh_key.id
  vpc_security_group_ids      = [aws_security_group.sg_web.id]
  user_data                   = file("web_server.cloud-config")
  tags = {
    Name = "Web_Server_EC2_Instance"
  }
}

### outputs

# S3 bucket info
output "s3_url" {
  value = aws_s3_bucket.s3_image.website_endpoint
}

# web server info
output "web_server_name" {
  value = aws_instance.ec2_web.public_dns
}

output "web_server_ip" {
  value = aws_instance.ec2_web.public_ip
}
