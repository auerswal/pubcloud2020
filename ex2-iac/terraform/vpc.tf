#   Terraform configuration for an AWS Virtual Private Cloud (VPC).
#   Copyright (C) 2020  Erik Auerswald <auerswal@unix-ag.uni-kl.de>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

# providers - AWS in this case
provider "aws" {
  version = "~> 2.52"
  profile = "default"
  region  = "eu-central-1"
}

# variables - prefix and name
variable "prefix" {
  default = "10.0.0.0/16"
}

variable "name" {
  default = "unnamed"
}

# resources - a VPC
resource "aws_vpc" "TheVPC" {
  cidr_block           = var.prefix
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = var.name
  }
}

# outputs - VPC ID and CIDR prefix
output "VPC_ID" {
  value = aws_vpc.TheVPC.id
}

output "Prefix" {
  value = aws_vpc.TheVPC.cidr_block
}
