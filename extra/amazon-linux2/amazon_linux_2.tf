# Terraform configuration for Amazon Linux 2 web server with 2nd ENI.
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

### variables

# CIDR prefixes to use
variable "vpc_prefix" {
  default = "10.42.0.0/16"
}
variable "priv_prefix" {
  default = "10.42.0.0/24"
}
variable "pub_prefix" {
  default = "10.42.255.0/24"
}

### data sources

# AMI ID for Amazon Linux 2 based web server
data "aws_ami" "gnu_linux_image" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.????????.?-x86_64-gp2"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

### resources

# public SSH key for remote access to EC2 instance
resource "aws_key_pair" "course_ssh_key" {
  key_name   = "tf-pubcloud2020"
  public_key = file("../../../pubcloud2020_rsa_id.pub")
}

# web server EC2 instance
resource "aws_instance" "ec2_web" {
  depends_on    = [aws_internet_gateway.igw]
  ami           = data.aws_ami.gnu_linux_image.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.course_ssh_key.id
  user_data     = file("web_server.cloud-config")
  tags = {
    Name = "Amazon Linux 2 Web Server EC2 Instance"
  }
}

# a new VPC for this deployment
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_prefix
  enable_dns_support   = true
  enable_dns_hostnames = true
  # dedicated hardware not needed -> use default tenancy
  instance_tenancy = "default"
  tags = {
    Name = "VPC"
  }
}

# a new (public) subnet in the new VPC
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pub_prefix
  map_public_ip_on_launch = true
  tags = {
    Name = "public subnet"
  }
}

# a new (private) subnet in the new VPC
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = aws_subnet.public.availability_zone
  cidr_block        = var.priv_prefix
  tags = {
    Name = "private subnet"
  }
}

# a new Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Internet gateway"
  }
}

# a new route table for the public subnet with default route to the IGW
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "route table for Internet access"
  }
}

# associate the route table with the public subnet
resource "aws_route_table_association" "rt2public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

# default Security Group of the new VPC
resource "aws_default_security_group" "def_sg" {
  vpc_id = aws_vpc.vpc.id
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
    Name = "Ex. 4 default Security Group"
  }
}

# elastic network interface
resource "aws_network_interface" "eni" {
  subnet_id = aws_subnet.private.id
  attachment {
    instance     = aws_instance.ec2_web.id
    device_index = 1
  }
}

### outputs

# CIDR prefixes and Availability Zones
output "VPC_prefix" {
  value = aws_vpc.vpc.cidr_block
}
output "private_subnet_prefix" {
  value = aws_subnet.private.cidr_block
}
output "private_subnet_az" {
  value = aws_subnet.private.availability_zone
}
output "public_subnet_prefix" {
  value = aws_subnet.public.cidr_block
}
output "public_subnet_az" {
  value = aws_subnet.public.availability_zone
}

# web server info
output "web_server_private_name" {
  value = aws_instance.ec2_web.private_dns
}
output "web_server_private_ip" {
  value = aws_instance.ec2_web.private_ip
}
output "web_server_public_name" {
  value = aws_instance.ec2_web.public_dns
}
output "web_server_public_ip" {
  value = aws_instance.ec2_web.public_ip
}

# ENI info
output "eni_private_ip" {
  value = aws_network_interface.eni.private_ip
}
