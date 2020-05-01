# Terraform configuration to control AWS S3 Public Access Block settings.
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

### variables - control S3 Public Access Block details (secure by default)
variable "block_public_acls" {
  default = true
}
variable "block_public_policy" {
  default = true
}
variable "ignore_public_acls" {
  default = true
}
variable "restrict_public_buckets" {
  default = true
}

### resources - control S3 Public Access Block - once per AWS account
resource "aws_s3_account_public_access_block" "s3_pab" {
  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}
