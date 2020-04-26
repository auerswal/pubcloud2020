# Terraform configuration for AWS virtual network infrastructure.
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

# select AMI flavor for VMs
variable "ami_owner" {
  default = "099720109477"
}
variable "ami_name" {
  default = "ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-server-????????"
}

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

### resources

# public SSH key for remote access to EC2 instances
resource "aws_key_pair" "course_ssh_key" {
  key_name   = "tf-pubcloud2020"
  public_key = file("../../../pubcloud2020_rsa_id.pub")
}

# a new VPC for this deployment
resource "aws_vpc" "ex4_vpc" {
  cidr_block           = var.vpc_prefix
  enable_dns_support   = true
  enable_dns_hostnames = true
  # dedicated hardware not needed -> use default tenancy
  instance_tenancy = "default"
  tags = {
    Name = "Ex. 4 VPC"
  }
}

# a new (public) subnet in the new VPC
resource "aws_subnet" "ex4_public" {
  vpc_id                  = aws_vpc.ex4_vpc.id
  cidr_block              = var.pub_prefix
  map_public_ip_on_launch = true
  tags = {
    Name = "Ex. 4 public subnet"
  }
}

# a new (private) subnet in the new VPC
resource "aws_subnet" "ex4_private" {
  vpc_id     = aws_vpc.ex4_vpc.id
  cidr_block = var.priv_prefix
  tags = {
    Name = "Ex. 4 private subnet"
  }
}

# a new Internet Gateway for the VPC
resource "aws_internet_gateway" "ex4_igw" {
  vpc_id = aws_vpc.ex4_vpc.id
  tags = {
    Name = "Ex. 4 Internet gateway"
  }
}

# a new route table for the public subnet with default route to the IGW
resource "aws_route_table" "ex4_rt" {
  vpc_id = aws_vpc.ex4_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ex4_igw.id
  }
  tags = {
    Name = "Ex. 4 route table for Internet access"
  }
}

# associate the route table with the public subnet
resource "aws_route_table_association" "rt2public" {
  subnet_id      = aws_subnet.ex4_public.id
  route_table_id = aws_route_table.ex4_rt.id
}

# default Security Group of the new VPC
resource "aws_default_security_group" "def_sg" {
  vpc_id = aws_vpc.ex4_vpc.id
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

# web server EC2 instance
resource "aws_instance" "ex4_web" {
  depends_on    = [aws_internet_gateway.ex4_igw]
  ami           = data.aws_ami.gnu_linux_image.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.ex4_public.id
  key_name      = aws_key_pair.course_ssh_key.id
  user_data     = file("web_server.cloud-config")
  tags = {
    Name = "Ex. 4 web server"
  }
}

# jump host EC2 instance
resource "aws_instance" "ex4_jump" {
  depends_on    = [aws_internet_gateway.ex4_igw]
  ami           = data.aws_ami.gnu_linux_image.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.ex4_public.id
  key_name      = aws_key_pair.course_ssh_key.id
  user_data     = file("jump_host.cloud-config")
  tags = {
    Name = "Ex. 4 jump host"
  }
}

# another EC2 instance
resource "aws_instance" "ex4_other" {
  ami           = data.aws_ami.gnu_linux_image.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.ex4_private.id
  key_name      = aws_key_pair.course_ssh_key.id
  user_data     = file("another.cloud-config")
  tags = {
    Name = "Ex. 4 private host"
  }
}

# elastic IP address
resource "aws_eip" "ex4_eip" {
  instance = aws_instance.ex4_web.id
  vpc      = true
}

# elastic network interface
resource "aws_network_interface" "ex4_eni" {
  subnet_id = aws_subnet.ex4_private.id
  attachment {
    instance     = aws_instance.ex4_jump.id
    device_index = 1
  }
}

### outputs

# CIDR prefixes
output "VPC_prefix" {
  value = aws_vpc.ex4_vpc.cidr_block
}
output "private_subnet_prefix" {
  value = aws_subnet.ex4_private.cidr_block
}
output "public_subnet_prefix" {
  value = aws_subnet.ex4_public.cidr_block
}

# web server info (probably wrong b/c of EIP)
output "web_server_name" {
  value = aws_instance.ex4_web.public_dns
}
output "web_server_ip" {
  value = aws_instance.ex4_web.public_ip
}
output "web_server_private_name" {
  value = aws_instance.ex4_web.private_dns
}
output "web_server_private_ip" {
  value = aws_instance.ex4_web.private_ip
}

# jump host info
output "jump_host_name" {
  value = aws_instance.ex4_jump.public_dns
}
output "jump_host_ip" {
  value = aws_instance.ex4_jump.public_ip
}
output "jump_host_privat_name" {
  value = aws_instance.ex4_jump.private_dns
}
output "jump_host_privat_ip" {
  value = aws_instance.ex4_jump.private_ip
}

# private host info
output "private_host_name" {
  value = aws_instance.ex4_other.private_dns
}
output "private_host_ip" {
  value = aws_instance.ex4_other.private_ip
}

# EIP info
output "eip_ip" {
  value = aws_eip.ex4_eip.public_ip
}
output "eip_name" {
  value = aws_eip.ex4_eip.public_dns
}
output "eip_private_ip" {
  value = aws_eip.ex4_eip.private_ip
}
output "eip_private_name" {
  value = aws_eip.ex4_eip.private_dns
}

# ENI info
output "eni_private_ip" {
  value = aws_network_interface.ex4_eni.private_ip
}
