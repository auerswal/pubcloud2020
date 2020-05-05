# Exercise 5: Deploy IPv6 in Your Cloud Virtual Network

In this hands-on exercise,
IPv6 shall be added to the virtual networking infrastructure from the
[previous](../ex4-infra/)
exercise using a *dual stack* approach.

I expect this to be relatively straight forward,
because AWS generally provides dual stack IPv6 support,
and the GNU/Linux operating system used for EC2 instances does as well.

At a first glance,
only the *elastic IP address* (EIP) does not support IPv6.
This is one element to look out for.
While the EIP *replaces* the public IP address
that can be allocated to an EC2 instance,
how does it interact with an IPv6 address allocated to the EC2 instance?

At a high level I'd say I need to implement three things:

1. Add IPv6 to every IPv4 part of the Terraform configuration.
2. Enable IPv6 on the EC2 instances (this might be a *no-op*).
3. Add IPv6 to the connectivity test script.

## Terraform Configuration

I have added IPv6 related arguments to the appropriate Terraform resources.
Not all of those are actually documented,
so this does require some trial and error.
Not all Terraform resources are dual-stack enabled yet,
e.g., the ENI resource does not provide an IPv6 attribute.

Terraform does not provide additional DNS name attributes for IPv6 addresses,
and the reported DNS name has just an A record.

A Security Group Rule can be specified with *both* IPv4 and IPv6 ranges,
but then only the IPv4 rules are active.
Terraform just accepts this *dual-stack* rule and deploys it without errors,
it just does not allow IPv6 access.
The security rules need to be manually synchronized between IPv4 and IPv6.
This might be possible by defining appropriate modules.

The Terraform configuration is saved in the file
[vni.tf](terraform/vni.tf).
The cloud-init configurations files
[another.cloud-config](terraform/another.cloud-config),
[jump\_host.cloud-config](terraform/jump_host.cloud-config),
and
[web\_server.cloud-config](terraform/web_server.cloud-config)
are identical to those from exercise 4.

So I perform the usual Terraform dance:

```
$ terraform fmt
vni.tf
```
```
$ terraform init

Initializing the backend...

Initializing provider plugins...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
```
$ terraform validate
Success! The configuration is valid.

```
```
$ terraform apply
data.aws_ami.gnu_linux_image: Refreshing state...

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_default_security_group.def_sg will be created
  + resource "aws_default_security_group" "def_sg" {
      + arn                    = (known after apply)
      + description            = (known after apply)
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "Allow legacy Internet access for, e.g., updates"
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
            },
          + {
              + cidr_blocks      = []
              + description      = "Allow Internet access for, e.g., updates"
              + from_port        = 0
              + ipv6_cidr_blocks = [
                  + "::/0",
                ]
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "Allow HTTP from the legacy Internet"
              + from_port        = 80
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 80
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "Allow HTTPS from the legacy Internet"
              + from_port        = 443
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 443
            },
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "Allow SSH from the legacy Internet"
              + from_port        = 22
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 22
            },
          + {
              + cidr_blocks      = []
              + description      = "Allow HTTP from the Internet"
              + from_port        = 80
              + ipv6_cidr_blocks = [
                  + "::/0",
                ]
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 80
            },
          + {
              + cidr_blocks      = []
              + description      = "Allow HTTPS from the Internet"
              + from_port        = 443
              + ipv6_cidr_blocks = [
                  + "::/0",
                ]
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 443
            },
          + {
              + cidr_blocks      = []
              + description      = "Allow SSH from the Internet"
              + from_port        = 22
              + ipv6_cidr_blocks = [
                  + "::/0",
                ]
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 22
            },
          + {
              + cidr_blocks      = []
              + description      = "Allow everything inside the SG"
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = true
              + to_port          = 0
            },
        ]
      + name                   = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name" = "Ex. 5 default Security Group"
        }
      + vpc_id                 = (known after apply)
    }

  # aws_eip.ex5_eip will be created
  + resource "aws_eip" "ex5_eip" {
      + allocation_id     = (known after apply)
      + association_id    = (known after apply)
      + domain            = (known after apply)
      + id                = (known after apply)
      + instance          = (known after apply)
      + network_interface = (known after apply)
      + private_dns       = (known after apply)
      + private_ip        = (known after apply)
      + public_dns        = (known after apply)
      + public_ip         = (known after apply)
      + public_ipv4_pool  = (known after apply)
      + vpc               = true
    }

  # aws_instance.ex5_jump will be created
  + resource "aws_instance" "ex5_jump" {
      + ami                          = "ami-0e342d72b12109f91"
      + arn                          = (known after apply)
      + associate_public_ip_address  = (known after apply)
      + availability_zone            = (known after apply)
      + cpu_core_count               = (known after apply)
      + cpu_threads_per_core         = (known after apply)
      + get_password_data            = false
      + host_id                      = (known after apply)
      + id                           = (known after apply)
      + instance_state               = (known after apply)
      + instance_type                = "t2.micro"
      + ipv6_address_count           = (known after apply)
      + ipv6_addresses               = (known after apply)
      + key_name                     = (known after apply)
      + network_interface_id         = (known after apply)
      + password_data                = (known after apply)
      + placement_group              = (known after apply)
      + primary_network_interface_id = (known after apply)
      + private_dns                  = (known after apply)
      + private_ip                   = (known after apply)
      + public_dns                   = (known after apply)
      + public_ip                    = (known after apply)
      + security_groups              = (known after apply)
      + source_dest_check            = true
      + subnet_id                    = (known after apply)
      + tags                         = {
          + "Name" = "Ex. 5 jump host"
        }
      + tenancy                      = (known after apply)
      + user_data                    = "da8a0e3140565957194df30dbb81ec736f2cb054"
      + volume_tags                  = (known after apply)
      + vpc_security_group_ids       = (known after apply)

      + ebs_block_device {
          + delete_on_termination = (known after apply)
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + snapshot_id           = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }

      + ephemeral_block_device {
          + device_name  = (known after apply)
          + no_device    = (known after apply)
          + virtual_name = (known after apply)
        }

      + network_interface {
          + delete_on_termination = (known after apply)
          + device_index          = (known after apply)
          + network_interface_id  = (known after apply)
        }

      + root_block_device {
          + delete_on_termination = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }
    }

  # aws_instance.ex5_other will be created
  + resource "aws_instance" "ex5_other" {
      + ami                          = "ami-0e342d72b12109f91"
      + arn                          = (known after apply)
      + associate_public_ip_address  = (known after apply)
      + availability_zone            = (known after apply)
      + cpu_core_count               = (known after apply)
      + cpu_threads_per_core         = (known after apply)
      + get_password_data            = false
      + host_id                      = (known after apply)
      + id                           = (known after apply)
      + instance_state               = (known after apply)
      + instance_type                = "t2.micro"
      + ipv6_address_count           = (known after apply)
      + ipv6_addresses               = (known after apply)
      + key_name                     = (known after apply)
      + network_interface_id         = (known after apply)
      + password_data                = (known after apply)
      + placement_group              = (known after apply)
      + primary_network_interface_id = (known after apply)
      + private_dns                  = (known after apply)
      + private_ip                   = (known after apply)
      + public_dns                   = (known after apply)
      + public_ip                    = (known after apply)
      + security_groups              = (known after apply)
      + source_dest_check            = true
      + subnet_id                    = (known after apply)
      + tags                         = {
          + "Name" = "Ex. 5 private host"
        }
      + tenancy                      = (known after apply)
      + user_data                    = "455b01c87a20b41630a012c794e4d53d8cda1d75"
      + volume_tags                  = (known after apply)
      + vpc_security_group_ids       = (known after apply)

      + ebs_block_device {
          + delete_on_termination = (known after apply)
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + snapshot_id           = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }

      + ephemeral_block_device {
          + device_name  = (known after apply)
          + no_device    = (known after apply)
          + virtual_name = (known after apply)
        }

      + network_interface {
          + delete_on_termination = (known after apply)
          + device_index          = (known after apply)
          + network_interface_id  = (known after apply)
        }

      + root_block_device {
          + delete_on_termination = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }
    }

  # aws_instance.ex5_web will be created
  + resource "aws_instance" "ex5_web" {
      + ami                          = "ami-0e342d72b12109f91"
      + arn                          = (known after apply)
      + associate_public_ip_address  = (known after apply)
      + availability_zone            = (known after apply)
      + cpu_core_count               = (known after apply)
      + cpu_threads_per_core         = (known after apply)
      + get_password_data            = false
      + host_id                      = (known after apply)
      + id                           = (known after apply)
      + instance_state               = (known after apply)
      + instance_type                = "t2.micro"
      + ipv6_address_count           = (known after apply)
      + ipv6_addresses               = (known after apply)
      + key_name                     = (known after apply)
      + network_interface_id         = (known after apply)
      + password_data                = (known after apply)
      + placement_group              = (known after apply)
      + primary_network_interface_id = (known after apply)
      + private_dns                  = (known after apply)
      + private_ip                   = (known after apply)
      + public_dns                   = (known after apply)
      + public_ip                    = (known after apply)
      + security_groups              = (known after apply)
      + source_dest_check            = true
      + subnet_id                    = (known after apply)
      + tags                         = {
          + "Name" = "Ex. 5 web server"
        }
      + tenancy                      = (known after apply)
      + user_data                    = "6197aaec194f10c08caf60960ec297a41f695ad2"
      + volume_tags                  = (known after apply)
      + vpc_security_group_ids       = (known after apply)

      + ebs_block_device {
          + delete_on_termination = (known after apply)
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + snapshot_id           = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }

      + ephemeral_block_device {
          + device_name  = (known after apply)
          + no_device    = (known after apply)
          + virtual_name = (known after apply)
        }

      + network_interface {
          + delete_on_termination = (known after apply)
          + device_index          = (known after apply)
          + network_interface_id  = (known after apply)
        }

      + root_block_device {
          + delete_on_termination = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }
    }

  # aws_internet_gateway.ex5_igw will be created
  + resource "aws_internet_gateway" "ex5_igw" {
      + id       = (known after apply)
      + owner_id = (known after apply)
      + tags     = {
          + "Name" = "Ex. 5 Internet gateway"
        }
      + vpc_id   = (known after apply)
    }

  # aws_key_pair.course_ssh_key will be created
  + resource "aws_key_pair" "course_ssh_key" {
      + fingerprint = (known after apply)
      + id          = (known after apply)
      + key_name    = "tf-pubcloud2020"
      + key_pair_id = (known after apply)
      + public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDiXuVGxn6zqLCPKbcojNC813FAnOPBWToBz/XTQaMzMsoAeKMRwVrUoyHEVj8UTFiuEUbTz/0jHItv5ZmFXI1DNY1m+hXxCDVcBp8ojCutX3+AJ012qG2PIZaloaYCjrTkhHj9VmMHAl1jzJ0EbPsoU/Qc4pZCNUNaCVCkG6EHisOUy9wx20i4gA/nrDnjIxk9TD2mGdlVCK7SESH/vGWgMtU6fLI65trtC4eojPNNUyMq8tTLyJxoTdYEwMY5alKkcjjw6+yVBOrtYgZSlMW02WLTkJT7eCxwVHig8a+bywiwAxuvYlUgfmOHEGEIXXTGk/+KNiLrDXdmkK4kuUvlf6rD7qR/kedqQAt0k5v/PiW3ufpej7n1ZBZroSsBT/0Yp5UcCLxpzskUYu+TRLRp+6gI50KsNe/oT8tesNtOVTK2ePD4eXApXAYwQpXy1389c4gGgh4wWljmHyeoFjcd4Soq847/PNspRdswR/u5jyswTsCROKsCJ4+whJRme8JoqaZHGBTpTu9n6gaZJVXbFM/55RYh0bpuCD5BHrdk0+HX4BmhJ1KqdDTDR84y2riwlpv6Eiw8AX8N2GVLOpP6RMt/AUCNUEy5nPWJosKb+UQE/j1dRJ9iorm2EGbh30dv/nRCb2Cu7BVyNWbmSrVaKdJub28SfV5L51sd+ATBw== auerswald@short"
    }

  # aws_network_interface.ex5_eni will be created
  + resource "aws_network_interface" "ex5_eni" {
      + id                = (known after apply)
      + mac_address       = (known after apply)
      + private_dns_name  = (known after apply)
      + private_ip        = (known after apply)
      + private_ips       = (known after apply)
      + private_ips_count = (known after apply)
      + security_groups   = (known after apply)
      + source_dest_check = true
      + subnet_id         = (known after apply)

      + attachment {
          + attachment_id = (known after apply)
          + device_index  = 1
          + instance      = (known after apply)
        }
    }

  # aws_route_table.ex5_rt will be created
  + resource "aws_route_table" "ex5_rt" {
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
          + {
              + cidr_block                = ""
              + egress_only_gateway_id    = ""
              + gateway_id                = (known after apply)
              + instance_id               = ""
              + ipv6_cidr_block           = "::/0"
              + nat_gateway_id            = ""
              + network_interface_id      = ""
              + transit_gateway_id        = ""
              + vpc_peering_connection_id = ""
            },
          + {
              + cidr_block                = "0.0.0.0/0"
              + egress_only_gateway_id    = ""
              + gateway_id                = (known after apply)
              + instance_id               = ""
              + ipv6_cidr_block           = ""
              + nat_gateway_id            = ""
              + network_interface_id      = ""
              + transit_gateway_id        = ""
              + vpc_peering_connection_id = ""
            },
        ]
      + tags             = {
          + "Name" = "Ex. 5 route table for Internet access"
        }
      + vpc_id           = (known after apply)
    }

  # aws_route_table_association.rt2public will be created
  + resource "aws_route_table_association" "rt2public" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_subnet.ex5_private will be created
  + resource "aws_subnet" "ex5_private" {
      + arn                             = (known after apply)
      + assign_ipv6_address_on_creation = true
      + availability_zone               = (known after apply)
      + availability_zone_id            = (known after apply)
      + cidr_block                      = "10.42.0.0/24"
      + id                              = (known after apply)
      + ipv6_cidr_block                 = (known after apply)
      + ipv6_cidr_block_association_id  = (known after apply)
      + map_public_ip_on_launch         = false
      + owner_id                        = (known after apply)
      + tags                            = {
          + "Name" = "Ex. 5 private subnet"
        }
      + vpc_id                          = (known after apply)
    }

  # aws_subnet.ex5_public will be created
  + resource "aws_subnet" "ex5_public" {
      + arn                             = (known after apply)
      + assign_ipv6_address_on_creation = true
      + availability_zone               = (known after apply)
      + availability_zone_id            = (known after apply)
      + cidr_block                      = "10.42.255.0/24"
      + id                              = (known after apply)
      + ipv6_cidr_block                 = (known after apply)
      + ipv6_cidr_block_association_id  = (known after apply)
      + map_public_ip_on_launch         = true
      + owner_id                        = (known after apply)
      + tags                            = {
          + "Name" = "Ex. 5 public subnet"
        }
      + vpc_id                          = (known after apply)
    }

  # aws_vpc.ex5_vpc will be created
  + resource "aws_vpc" "ex5_vpc" {
      + arn                              = (known after apply)
      + assign_generated_ipv6_cidr_block = true
      + cidr_block                       = "10.42.0.0/16"
      + default_network_acl_id           = (known after apply)
      + default_route_table_id           = (known after apply)
      + default_security_group_id        = (known after apply)
      + dhcp_options_id                  = (known after apply)
      + enable_classiclink               = (known after apply)
      + enable_classiclink_dns_support   = (known after apply)
      + enable_dns_hostnames             = true
      + enable_dns_support               = true
      + id                               = (known after apply)
      + instance_tenancy                 = "default"
      + ipv6_association_id              = (known after apply)
      + ipv6_cidr_block                  = (known after apply)
      + main_route_table_id              = (known after apply)
      + owner_id                         = (known after apply)
      + tags                             = {
          + "Name" = "Ex. 5 VPC"
        }
    }

Plan: 13 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_key_pair.course_ssh_key: Creating...
aws_vpc.ex5_vpc: Creating...
aws_key_pair.course_ssh_key: Creation complete after 1s [id=tf-pubcloud2020]
aws_vpc.ex5_vpc: Still creating... [10s elapsed]
aws_vpc.ex5_vpc: Creation complete after 10s [id=vpc-04f585514ab5ec161]
aws_internet_gateway.ex5_igw: Creating...
aws_subnet.ex5_public: Creating...
aws_default_security_group.def_sg: Creating...
aws_internet_gateway.ex5_igw: Creation complete after 5s [id=igw-0ef58e1d1ce3489e1]
aws_route_table.ex5_rt: Creating...
aws_subnet.ex5_public: Creation complete after 6s [id=subnet-046c8e11ac4d61aa6]
aws_subnet.ex5_private: Creating...
aws_instance.ex5_web: Creating...
aws_instance.ex5_jump: Creating...
aws_default_security_group.def_sg: Creation complete after 7s [id=sg-042aa7ca49f876157]
aws_route_table.ex5_rt: Creation complete after 5s [id=rtb-05d0ba9924182bf02]
aws_route_table_association.rt2public: Creating...
aws_subnet.ex5_private: Creation complete after 4s [id=subnet-05b20cf22dd103de1]
aws_instance.ex5_other: Creating...
aws_route_table_association.rt2public: Creation complete after 1s [id=rtbassoc-0646371af14e79905]
aws_instance.ex5_web: Still creating... [10s elapsed]
aws_instance.ex5_jump: Still creating... [10s elapsed]
aws_instance.ex5_other: Still creating... [10s elapsed]
aws_instance.ex5_web: Still creating... [20s elapsed]
aws_instance.ex5_jump: Still creating... [20s elapsed]
aws_instance.ex5_other: Still creating... [20s elapsed]
aws_instance.ex5_web: Creation complete after 28s [id=i-06a96d6208037a770]
aws_eip.ex5_eip: Creating...
aws_instance.ex5_jump: Creation complete after 29s [id=i-0ac15e232945ef2f8]
aws_network_interface.ex5_eni: Creating...
aws_eip.ex5_eip: Creation complete after 2s [id=eipalloc-06d509fb0f3bb5078]
aws_instance.ex5_other: Creation complete after 27s [id=i-0802bd9e2a13f4cc1]
aws_network_interface.ex5_eni: Creation complete after 3s [id=eni-08910e02f4dc4c07c]

Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

Outputs:

VPC_v4_prefix = 10.42.0.0/16
VPC_v6_prefix = 2a05:d014:bab:2f00::/56
eip_ip = 18.156.167.26
eip_name = ec2-18-156-167-26.eu-central-1.compute.amazonaws.com
eip_private_ip = 10.42.255.136
eip_private_name = ip-10-42-255-136.eu-central-1.compute.internal
eni_private_ipv4 = 10.42.0.163
jump_host_ipv4 = 3.122.252.181
jump_host_ipv6 = [
  "2a05:d014:bab:2fff:c10b:20a9:a9f7:385f",
]
jump_host_name = ec2-3-122-252-181.eu-central-1.compute.amazonaws.com
jump_host_privat_ipv4 = 10.42.255.50
jump_host_privat_name = ip-10-42-255-50.eu-central-1.compute.internal
private_host_ipv4 = 10.42.0.236
private_host_ipv6 = [
  "2a05:d014:bab:2f00:9b5a:73a5:287c:f8c",
]
private_host_name = ip-10-42-0-236.eu-central-1.compute.internal
private_subnet_v4_prefix = 10.42.0.0/24
private_subnet_v6_prefix = 2a05:d014:bab:2f00::/64
public_subnet_v4_prefix = 10.42.255.0/24
public_subnet_v6_prefix = 2a05:d014:bab:2fff::/64
web_server_ipv4 = 3.126.130.81
web_server_ipv6 = [
  "2a05:d014:bab:2fff:f646:2b45:e501:148c",
]
web_server_name = ec2-3-126-130-81.eu-central-1.compute.amazonaws.com
web_server_private_ipv4 = 10.42.255.136
web_server_private_name = ip-10-42-255-136.eu-central-1.compute.internal
```

## No EC2 Instance Changes

As expected, the GNU/Linux based EC2 instances do not need any changes
to enable dual-stack IPv4 and IPv6 operation.
This includes the Apache web server on Ubuntu 18.04 LTS.

But the defaults result in a broken multihoming configuration for IPv6,
which affects the jump host in my deployment.
The IPv4 multihoming configuration is not perfect either,
but it at least works for the tests.
IPv4 is probably broken for some connections originating on the jump host.

The multihoming problems are quite tricky,
because they only affect *some* communications.
Thus connectivity tests sometimes succeed, sometimes fail.
With IPv4, connecting *to* the multihomed host works,
and connecting *from* it to a destination inside the VPC does as well.
With IPv6 this cannot be said any more.

## Connectivity Test

Manual connectivity testing shows that the ENI does have an IPv6 address,
but Terraform does not know about it.
Thus I cannot extract this information from the Terraform status file.
I can extract the ENI ID from the Terraform state,
and then use the AWS CLI to retrieve the ENI attributes.

Basic connectivity works,
but IPv6 connectivity is broken for the jump host
due to the second elastic network interface.
I have adjusted the
[`connectivity_test`](connectivity_test)
to omit testing the broken parts. :-/

```
$ ./connectivity_test 
--> determining IPv4 and IPv6 addresses, and DNS names...
--> web server EIP IP:       18.156.167.26
--> web server EIP DNS:      ec2-18-156-167-26.eu-central-1.compute.amazonaws.com
--> web server IPv6:         2a05:d014:bab:2fff:f646:2b45:e501:148c
--> web server private IPv4: 10.42.255.136
--> jump host IPv4:          3.122.252.181
--> jump host DNS:           ec2-3-122-252-181.eu-central-1.compute.amazonaws.com
--> jump host IPv6:          2a05:d014:bab:2fff:c10b:20a9:a9f7:385f
--> jump host 2nd IPv6:      2a05:d014:bab:2f00:e838:337d:27f7:7c0a
--> other host IPv4:         10.42.0.236
--> other host IPv6:         2a05:d014:bab:2f00:9b5a:73a5:287c:f8c
--> connecting via SSH to elastic IP address via IPv4 address...
Warning: Permanently added '18.156.167.26' (ECDSA) to the list of known hosts.
--> OK
--> connecting via SSH to jump server via IPv4 address...
Warning: Permanently added '3.122.252.181' (ECDSA) to the list of known hosts.
--> OK
--> accessing web page via IPv4 address...
--> OK
--> check that jump host is no web server (via IPv4)...
--> OK
--> connecting via SSH to elastic IP address via DNS name...
Warning: Permanently added 'ec2-18-156-167-26.eu-central-1.compute.amazonaws.com,18.156.167.26' (ECDSA) to the list of known hosts.
--> OK
--> connecting via SSH to web server via IPv6 address...
Warning: Permanently added '2a05:d014:bab:2fff:f646:2b45:e501:148c' (ECDSA) to the list of known hosts.
--> OK
--> accessing web page via DNS name...
--> OK
--> connecting via SSH to jump server via DNS name...
Warning: Permanently added 'ec2-3-122-252-181.eu-central-1.compute.amazonaws.com,3.122.252.181' (ECDSA) to the list of known hosts.
--> OK
--> check that jump host is no web server (via DNS)...
--> OK
--> accessing web page via IPv6 address...
--> OK
--> check that global IPv6 does not allow SSH access to private subnet...
ssh: connect to host 2a05:d014:bab:2f00:9b5a:73a5:287c:f8c port 22: Connection timed out
--> OK
--> connecting via SSH via jump host to host on private subnet...
---> using private IPv4 address
Warning: Permanently added '10.42.0.236' (ECDSA) to the list of known hosts.
--> OK
--> testing internal IPv4 connectivity of host on private subnet...
Warning: Permanently added '10.42.0.236' (ECDSA) to the list of known hosts.
PING 10.42.255.136 (10.42.255.136) 56(84) bytes of data.
64 bytes from 10.42.255.136: icmp_seq=1 ttl=64 time=0.376 ms
64 bytes from 10.42.255.136: icmp_seq=2 ttl=64 time=0.428 ms

--- 10.42.255.136 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1011ms
rtt min/avg/max/mdev = 0.376/0.402/0.428/0.026 ms
--> OK
--> testing internal IPv6 connectivity of host on private subnet...
Warning: Permanently added '10.42.0.236' (ECDSA) to the list of known hosts.
PING 2a05:d014:bab:2fff:f646:2b45:e501:148c(2a05:d014:bab:2fff:f646:2b45:e501:148c) 56 data bytes
64 bytes from 2a05:d014:bab:2fff:f646:2b45:e501:148c: icmp_seq=1 ttl=64 time=0.426 ms
64 bytes from 2a05:d014:bab:2fff:f646:2b45:e501:148c: icmp_seq=2 ttl=64 time=0.414 ms

--- 2a05:d014:bab:2fff:f646:2b45:e501:148c ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1019ms
rtt min/avg/max/mdev = 0.414/0.420/0.426/0.006 ms
--> OK
--> testing for no external v4 connectivity of host on private subnet...
Warning: Permanently added '10.42.0.236' (ECDSA) to the list of known hosts.
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.

--- 8.8.8.8 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1014ms

--> OK
--> testing for no external v6 connectivity of host on private subnet...
Warning: Permanently added '10.42.0.236' (ECDSA) to the list of known hosts.
PING 2001:4860:4860::8888(2001:4860:4860::8888) 56 data bytes

--- 2001:4860:4860::8888 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1011ms

--> OK

==> All tests passed successfully. :-)

```

The Ubuntu jump host learns two default routes each for both IPv4 and IPv6.
One default route uses the first elastic network interface,
the other uses the second.
Only the first ENI is connected to a subnet with a real default route.
While this does work with IPv4,
it does not work with IPv6.

The situation looked as follows during one test:

```
$ ssh ubuntu@52.57.116.221 ip -6 r s ::/0
default proto ra metric 100
        nexthop via fe80::48e:83ff:fe3b:8920 dev eth1 weight 1
        nexthop via fe80::493:21ff:fedf:f73e dev eth0 weight 1
```
```
$ ssh ubuntu@52.57.116.221 ip -4 r s 0.0.0.0/0
default via 10.42.255.1 dev eth0 proto dhcp src 10.42.255.22 metric 100
default via 10.42.0.1 dev eth1 proto dhcp src 10.42.0.163 metric 100
```

The one IPv6 default route looks worse than the two IPv4 default routes,
because it uses two *nexthops* for one route.
Thus the source address used for reply packets does not help the Linux kernel
select the *correct* route, i.e., the *correct nexthop* of the *single* route.
This is different in IPv4 with two default routes.

It is simple to activate IPv6 in AWS,
but that does not mean that everything *just works*,
especially not the same as with IPv4.

## Down the Rabbit Hole

As the Ancients told us in
[RFC 1122, section 3.3.4.1](https://tools.ietf.org/html/rfc1122#section-3.3.4.1),
parapgraph (c):

> This case presents the most difficult routing problems.
> The choice of interface (i.e., the choice of first-hop
> network) may significantly affect performance or even
> reachability of remote parts of the Internet.

Those wise sages could predict the problems we encountered with the
then unknown IP protocol version 6.

The jump host has learned of two routers via Router Advertisements.
It regards both as potential default gateways.
It cannot know if one is better than the other.
Thus it sometimes chooses the wrong gateway.

We could manually remove the unwanted nexthop from the default route,
but due to periodic RAs it might come back.
Even configuration learned via (any current version of) DHCP,
but manually removed afterwards,
may come back when the DHCP lease is renewed.

Instead of relying on automatic address configuration,
we might consider manual configuration.
I do not think this is advisable.

AWS could implement
[RFC 4191](https://tools.ietf.org/html/rfc4191)
*Default Router Preferences and More-Specific Routes*
to send different RAs that distinguish between public and private subnets.
The private subnet gateway could use a worse router preference.
This could be implemented as a *nerd knob* of the *subnet* object.
This could even result in a better IPv6 experience than the IPv4 one now.
I won't hold my breath…

## Just Say No!

My advice would be to use neither multihoming
nor private subnets on AWS.

Use routing to create full connectivity,
then apply security controls to restrict it.
Translated to AWS that means subnets with complete routing tables
for connectivity,
and Security Groups to restrict communication.

The AWS subnet construct is needed for Availability Zone use,
but not for communication restrictions.

But as Tony Hoare said in his
[Turing Award lecture](https://dl.acm.org/doi/10.1145/358549.358561):

> To have our best advice ignored is the common fate of all who take on
> the role of consultant, ever since Cassandra pointed out the dangers
> of bringing a wooden horse within the walls of Troy.

## Cleaning Up

As always, I destroy the cloud deployment:

```
$ terraform destroy
aws_key_pair.course_ssh_key: Refreshing state... [id=tf-pubcloud2020]
aws_vpc.ex5_vpc: Refreshing state... [id=vpc-04f585514ab5ec161]
data.aws_ami.gnu_linux_image: Refreshing state...
aws_subnet.ex5_public: Refreshing state... [id=subnet-046c8e11ac4d61aa6]
aws_internet_gateway.ex5_igw: Refreshing state... [id=igw-0ef58e1d1ce3489e1]
aws_default_security_group.def_sg: Refreshing state... [id=sg-042aa7ca49f876157]
aws_subnet.ex5_private: Refreshing state... [id=subnet-05b20cf22dd103de1]
aws_instance.ex5_jump: Refreshing state... [id=i-0ac15e232945ef2f8]
aws_route_table.ex5_rt: Refreshing state... [id=rtb-05d0ba9924182bf02]
aws_instance.ex5_web: Refreshing state... [id=i-06a96d6208037a770]
aws_instance.ex5_other: Refreshing state... [id=i-0802bd9e2a13f4cc1]
aws_route_table_association.rt2public: Refreshing state... [id=rtbassoc-0646371af14e79905]
aws_eip.ex5_eip: Refreshing state... [id=eipalloc-06d509fb0f3bb5078]
aws_network_interface.ex5_eni: Refreshing state... [id=eni-08910e02f4dc4c07c]

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # aws_default_security_group.def_sg will be destroyed
  - resource "aws_default_security_group" "def_sg" {
      - arn                    = "arn:aws:ec2:eu-central-1:143440624024:security-group/sg-042aa7ca49f876157" -> null
      - description            = "default VPC security group" -> null
      - egress                 = [
          - {
              - cidr_blocks      = [
                  - "0.0.0.0/0",
                ]
              - description      = "Allow legacy Internet access for, e.g., updates"
              - from_port        = 0
              - ipv6_cidr_blocks = []
              - prefix_list_ids  = []
              - protocol         = "-1"
              - security_groups  = []
              - self             = false
              - to_port          = 0
            },
          - {
              - cidr_blocks      = []
              - description      = "Allow Internet access for, e.g., updates"
              - from_port        = 0
              - ipv6_cidr_blocks = [
                  - "::/0",
                ]
              - prefix_list_ids  = []
              - protocol         = "-1"
              - security_groups  = []
              - self             = false
              - to_port          = 0
            },
        ] -> null
      - id                     = "sg-042aa7ca49f876157" -> null
      - ingress                = [
          - {
              - cidr_blocks      = [
                  - "0.0.0.0/0",
                ]
              - description      = "Allow HTTP from the legacy Internet"
              - from_port        = 80
              - ipv6_cidr_blocks = []
              - prefix_list_ids  = []
              - protocol         = "tcp"
              - security_groups  = []
              - self             = false
              - to_port          = 80
            },
          - {
              - cidr_blocks      = [
                  - "0.0.0.0/0",
                ]
              - description      = "Allow HTTPS from the legacy Internet"
              - from_port        = 443
              - ipv6_cidr_blocks = []
              - prefix_list_ids  = []
              - protocol         = "tcp"
              - security_groups  = []
              - self             = false
              - to_port          = 443
            },
          - {
              - cidr_blocks      = [
                  - "0.0.0.0/0",
                ]
              - description      = "Allow SSH from the legacy Internet"
              - from_port        = 22
              - ipv6_cidr_blocks = []
              - prefix_list_ids  = []
              - protocol         = "tcp"
              - security_groups  = []
              - self             = false
              - to_port          = 22
            },
          - {
              - cidr_blocks      = []
              - description      = "Allow HTTP from the Internet"
              - from_port        = 80
              - ipv6_cidr_blocks = [
                  - "::/0",
                ]
              - prefix_list_ids  = []
              - protocol         = "tcp"
              - security_groups  = []
              - self             = false
              - to_port          = 80
            },
          - {
              - cidr_blocks      = []
              - description      = "Allow HTTPS from the Internet"
              - from_port        = 443
              - ipv6_cidr_blocks = [
                  - "::/0",
                ]
              - prefix_list_ids  = []
              - protocol         = "tcp"
              - security_groups  = []
              - self             = false
              - to_port          = 443
            },
          - {
              - cidr_blocks      = []
              - description      = "Allow SSH from the Internet"
              - from_port        = 22
              - ipv6_cidr_blocks = [
                  - "::/0",
                ]
              - prefix_list_ids  = []
              - protocol         = "tcp"
              - security_groups  = []
              - self             = false
              - to_port          = 22
            },
          - {
              - cidr_blocks      = []
              - description      = "Allow everything inside the SG"
              - from_port        = 0
              - ipv6_cidr_blocks = []
              - prefix_list_ids  = []
              - protocol         = "-1"
              - security_groups  = []
              - self             = true
              - to_port          = 0
            },
        ] -> null
      - name                   = "default" -> null
      - owner_id               = "143440624024" -> null
      - revoke_rules_on_delete = false -> null
      - tags                   = {
          - "Name" = "Ex. 5 default Security Group"
        } -> null
      - vpc_id                 = "vpc-04f585514ab5ec161" -> null
    }

  # aws_eip.ex5_eip will be destroyed
  - resource "aws_eip" "ex5_eip" {
      - association_id    = "eipassoc-0332f8e3195eb0f03" -> null
      - domain            = "vpc" -> null
      - id                = "eipalloc-06d509fb0f3bb5078" -> null
      - instance          = "i-06a96d6208037a770" -> null
      - network_interface = "eni-096a76dc14e9401d0" -> null
      - private_dns       = "ip-10-42-255-136.eu-central-1.compute.internal" -> null
      - private_ip        = "10.42.255.136" -> null
      - public_dns        = "ec2-18-156-167-26.eu-central-1.compute.amazonaws.com" -> null
      - public_ip         = "18.156.167.26" -> null
      - public_ipv4_pool  = "amazon" -> null
      - tags              = {} -> null
      - vpc               = true -> null
    }

  # aws_instance.ex5_jump will be destroyed
  - resource "aws_instance" "ex5_jump" {
      - ami                          = "ami-0e342d72b12109f91" -> null
      - arn                          = "arn:aws:ec2:eu-central-1:143440624024:instance/i-0ac15e232945ef2f8" -> null
      - associate_public_ip_address  = true -> null
      - availability_zone            = "eu-central-1b" -> null
      - cpu_core_count               = 1 -> null
      - cpu_threads_per_core         = 1 -> null
      - disable_api_termination      = false -> null
      - ebs_optimized                = false -> null
      - get_password_data            = false -> null
      - hibernation                  = false -> null
      - id                           = "i-0ac15e232945ef2f8" -> null
      - instance_state               = "running" -> null
      - instance_type                = "t2.micro" -> null
      - ipv6_address_count           = 1 -> null
      - ipv6_addresses               = [
          - "2a05:d014:bab:2fff:c10b:20a9:a9f7:385f",
        ] -> null
      - key_name                     = "tf-pubcloud2020" -> null
      - monitoring                   = false -> null
      - primary_network_interface_id = "eni-046eea763411aa719" -> null
      - private_dns                  = "ip-10-42-255-50.eu-central-1.compute.internal" -> null
      - private_ip                   = "10.42.255.50" -> null
      - public_dns                   = "ec2-3-122-252-181.eu-central-1.compute.amazonaws.com" -> null
      - public_ip                    = "3.122.252.181" -> null
      - security_groups              = [] -> null
      - source_dest_check            = true -> null
      - subnet_id                    = "subnet-046c8e11ac4d61aa6" -> null
      - tags                         = {
          - "Name" = "Ex. 5 jump host"
        } -> null
      - tenancy                      = "default" -> null
      - user_data                    = "da8a0e3140565957194df30dbb81ec736f2cb054" -> null
      - volume_tags                  = {} -> null
      - vpc_security_group_ids       = [
          - "sg-042aa7ca49f876157",
        ] -> null

      - credit_specification {
          - cpu_credits = "standard" -> null
        }

      - root_block_device {
          - delete_on_termination = true -> null
          - encrypted             = false -> null
          - iops                  = 100 -> null
          - volume_id             = "vol-09c9813ac0cacda8a" -> null
          - volume_size           = 8 -> null
          - volume_type           = "gp2" -> null
        }
    }

  # aws_instance.ex5_other will be destroyed
  - resource "aws_instance" "ex5_other" {
      - ami                          = "ami-0e342d72b12109f91" -> null
      - arn                          = "arn:aws:ec2:eu-central-1:143440624024:instance/i-0802bd9e2a13f4cc1" -> null
      - associate_public_ip_address  = false -> null
      - availability_zone            = "eu-central-1b" -> null
      - cpu_core_count               = 1 -> null
      - cpu_threads_per_core         = 1 -> null
      - disable_api_termination      = false -> null
      - ebs_optimized                = false -> null
      - get_password_data            = false -> null
      - hibernation                  = false -> null
      - id                           = "i-0802bd9e2a13f4cc1" -> null
      - instance_state               = "running" -> null
      - instance_type                = "t2.micro" -> null
      - ipv6_address_count           = 1 -> null
      - ipv6_addresses               = [
          - "2a05:d014:bab:2f00:9b5a:73a5:287c:f8c",
        ] -> null
      - key_name                     = "tf-pubcloud2020" -> null
      - monitoring                   = false -> null
      - primary_network_interface_id = "eni-08d1b7c30c6639f7e" -> null
      - private_dns                  = "ip-10-42-0-236.eu-central-1.compute.internal" -> null
      - private_ip                   = "10.42.0.236" -> null
      - security_groups              = [] -> null
      - source_dest_check            = true -> null
      - subnet_id                    = "subnet-05b20cf22dd103de1" -> null
      - tags                         = {
          - "Name" = "Ex. 5 private host"
        } -> null
      - tenancy                      = "default" -> null
      - user_data                    = "455b01c87a20b41630a012c794e4d53d8cda1d75" -> null
      - volume_tags                  = {} -> null
      - vpc_security_group_ids       = [
          - "sg-042aa7ca49f876157",
        ] -> null

      - credit_specification {
          - cpu_credits = "standard" -> null
        }

      - root_block_device {
          - delete_on_termination = true -> null
          - encrypted             = false -> null
          - iops                  = 100 -> null
          - volume_id             = "vol-0f7e48700a7080383" -> null
          - volume_size           = 8 -> null
          - volume_type           = "gp2" -> null
        }
    }

  # aws_instance.ex5_web will be destroyed
  - resource "aws_instance" "ex5_web" {
      - ami                          = "ami-0e342d72b12109f91" -> null
      - arn                          = "arn:aws:ec2:eu-central-1:143440624024:instance/i-06a96d6208037a770" -> null
      - associate_public_ip_address  = true -> null
      - availability_zone            = "eu-central-1b" -> null
      - cpu_core_count               = 1 -> null
      - cpu_threads_per_core         = 1 -> null
      - disable_api_termination      = false -> null
      - ebs_optimized                = false -> null
      - get_password_data            = false -> null
      - hibernation                  = false -> null
      - id                           = "i-06a96d6208037a770" -> null
      - instance_state               = "running" -> null
      - instance_type                = "t2.micro" -> null
      - ipv6_address_count           = 1 -> null
      - ipv6_addresses               = [
          - "2a05:d014:bab:2fff:f646:2b45:e501:148c",
        ] -> null
      - key_name                     = "tf-pubcloud2020" -> null
      - monitoring                   = false -> null
      - primary_network_interface_id = "eni-096a76dc14e9401d0" -> null
      - private_dns                  = "ip-10-42-255-136.eu-central-1.compute.internal" -> null
      - private_ip                   = "10.42.255.136" -> null
      - public_dns                   = "ec2-18-156-167-26.eu-central-1.compute.amazonaws.com" -> null
      - public_ip                    = "18.156.167.26" -> null
      - security_groups              = [] -> null
      - source_dest_check            = true -> null
      - subnet_id                    = "subnet-046c8e11ac4d61aa6" -> null
      - tags                         = {
          - "Name" = "Ex. 5 web server"
        } -> null
      - tenancy                      = "default" -> null
      - user_data                    = "6197aaec194f10c08caf60960ec297a41f695ad2" -> null
      - volume_tags                  = {} -> null
      - vpc_security_group_ids       = [
          - "sg-042aa7ca49f876157",
        ] -> null

      - credit_specification {
          - cpu_credits = "standard" -> null
        }

      - root_block_device {
          - delete_on_termination = true -> null
          - encrypted             = false -> null
          - iops                  = 100 -> null
          - volume_id             = "vol-0ea4dee5463e400a6" -> null
          - volume_size           = 8 -> null
          - volume_type           = "gp2" -> null
        }
    }

  # aws_internet_gateway.ex5_igw will be destroyed
  - resource "aws_internet_gateway" "ex5_igw" {
      - id       = "igw-0ef58e1d1ce3489e1" -> null
      - owner_id = "143440624024" -> null
      - tags     = {
          - "Name" = "Ex. 5 Internet gateway"
        } -> null
      - vpc_id   = "vpc-04f585514ab5ec161" -> null
    }

  # aws_key_pair.course_ssh_key will be destroyed
  - resource "aws_key_pair" "course_ssh_key" {
      - fingerprint = "bc:c0:ba:de:c1:2d:a8:38:5d:08:33:ba:dd:18:db:c4" -> null
      - id          = "tf-pubcloud2020" -> null
      - key_name    = "tf-pubcloud2020" -> null
      - key_pair_id = "key-03cde2ce52a967153" -> null
      - public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDiXuVGxn6zqLCPKbcojNC813FAnOPBWToBz/XTQaMzMsoAeKMRwVrUoyHEVj8UTFiuEUbTz/0jHItv5ZmFXI1DNY1m+hXxCDVcBp8ojCutX3+AJ012qG2PIZaloaYCjrTkhHj9VmMHAl1jzJ0EbPsoU/Qc4pZCNUNaCVCkG6EHisOUy9wx20i4gA/nrDnjIxk9TD2mGdlVCK7SESH/vGWgMtU6fLI65trtC4eojPNNUyMq8tTLyJxoTdYEwMY5alKkcjjw6+yVBOrtYgZSlMW02WLTkJT7eCxwVHig8a+bywiwAxuvYlUgfmOHEGEIXXTGk/+KNiLrDXdmkK4kuUvlf6rD7qR/kedqQAt0k5v/PiW3ufpej7n1ZBZroSsBT/0Yp5UcCLxpzskUYu+TRLRp+6gI50KsNe/oT8tesNtOVTK2ePD4eXApXAYwQpXy1389c4gGgh4wWljmHyeoFjcd4Soq847/PNspRdswR/u5jyswTsCROKsCJ4+whJRme8JoqaZHGBTpTu9n6gaZJVXbFM/55RYh0bpuCD5BHrdk0+HX4BmhJ1KqdDTDR84y2riwlpv6Eiw8AX8N2GVLOpP6RMt/AUCNUEy5nPWJosKb+UQE/j1dRJ9iorm2EGbh30dv/nRCb2Cu7BVyNWbmSrVaKdJub28SfV5L51sd+ATBw== auerswald@short" -> null
      - tags        = {} -> null
    }

  # aws_network_interface.ex5_eni will be destroyed
  - resource "aws_network_interface" "ex5_eni" {
      - id                = "eni-08910e02f4dc4c07c" -> null
      - mac_address       = "06:9a:8a:a1:36:cc" -> null
      - private_dns_name  = "ip-10-42-0-163.eu-central-1.compute.internal" -> null
      - private_ip        = "10.42.0.163" -> null
      - private_ips       = [
          - "10.42.0.163",
        ] -> null
      - private_ips_count = 0 -> null
      - security_groups   = [
          - "sg-042aa7ca49f876157",
        ] -> null
      - source_dest_check = true -> null
      - subnet_id         = "subnet-05b20cf22dd103de1" -> null
      - tags              = {} -> null

      - attachment {
          - attachment_id = "eni-attach-0b1b2673ec154d3ce" -> null
          - device_index  = 1 -> null
          - instance      = "i-0ac15e232945ef2f8" -> null
        }
    }

  # aws_route_table.ex5_rt will be destroyed
  - resource "aws_route_table" "ex5_rt" {
      - id               = "rtb-05d0ba9924182bf02" -> null
      - owner_id         = "143440624024" -> null
      - propagating_vgws = [] -> null
      - route            = [
          - {
              - cidr_block                = ""
              - egress_only_gateway_id    = ""
              - gateway_id                = "igw-0ef58e1d1ce3489e1"
              - instance_id               = ""
              - ipv6_cidr_block           = "::/0"
              - nat_gateway_id            = ""
              - network_interface_id      = ""
              - transit_gateway_id        = ""
              - vpc_peering_connection_id = ""
            },
          - {
              - cidr_block                = "0.0.0.0/0"
              - egress_only_gateway_id    = ""
              - gateway_id                = "igw-0ef58e1d1ce3489e1"
              - instance_id               = ""
              - ipv6_cidr_block           = ""
              - nat_gateway_id            = ""
              - network_interface_id      = ""
              - transit_gateway_id        = ""
              - vpc_peering_connection_id = ""
            },
        ] -> null
      - tags             = {
          - "Name" = "Ex. 5 route table for Internet access"
        } -> null
      - vpc_id           = "vpc-04f585514ab5ec161" -> null
    }

  # aws_route_table_association.rt2public will be destroyed
  - resource "aws_route_table_association" "rt2public" {
      - id             = "rtbassoc-0646371af14e79905" -> null
      - route_table_id = "rtb-05d0ba9924182bf02" -> null
      - subnet_id      = "subnet-046c8e11ac4d61aa6" -> null
    }

  # aws_subnet.ex5_private will be destroyed
  - resource "aws_subnet" "ex5_private" {
      - arn                             = "arn:aws:ec2:eu-central-1:143440624024:subnet/subnet-05b20cf22dd103de1" -> null
      - assign_ipv6_address_on_creation = true -> null
      - availability_zone               = "eu-central-1b" -> null
      - availability_zone_id            = "euc1-az3" -> null
      - cidr_block                      = "10.42.0.0/24" -> null
      - id                              = "subnet-05b20cf22dd103de1" -> null
      - ipv6_cidr_block                 = "2a05:d014:bab:2f00::/64" -> null
      - ipv6_cidr_block_association_id  = "subnet-cidr-assoc-08b251e13ed81e6b9" -> null
      - map_public_ip_on_launch         = false -> null
      - owner_id                        = "143440624024" -> null
      - tags                            = {
          - "Name" = "Ex. 5 private subnet"
        } -> null
      - vpc_id                          = "vpc-04f585514ab5ec161" -> null
    }

  # aws_subnet.ex5_public will be destroyed
  - resource "aws_subnet" "ex5_public" {
      - arn                             = "arn:aws:ec2:eu-central-1:143440624024:subnet/subnet-046c8e11ac4d61aa6" -> null
      - assign_ipv6_address_on_creation = true -> null
      - availability_zone               = "eu-central-1b" -> null
      - availability_zone_id            = "euc1-az3" -> null
      - cidr_block                      = "10.42.255.0/24" -> null
      - id                              = "subnet-046c8e11ac4d61aa6" -> null
      - ipv6_cidr_block                 = "2a05:d014:bab:2fff::/64" -> null
      - ipv6_cidr_block_association_id  = "subnet-cidr-assoc-0414461c3e23fa09a" -> null
      - map_public_ip_on_launch         = true -> null
      - owner_id                        = "143440624024" -> null
      - tags                            = {
          - "Name" = "Ex. 5 public subnet"
        } -> null
      - vpc_id                          = "vpc-04f585514ab5ec161" -> null
    }

  # aws_vpc.ex5_vpc will be destroyed
  - resource "aws_vpc" "ex5_vpc" {
      - arn                              = "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-04f585514ab5ec161" -> null
      - assign_generated_ipv6_cidr_block = true -> null
      - cidr_block                       = "10.42.0.0/16" -> null
      - default_network_acl_id           = "acl-090ca4a09f4d72eb0" -> null
      - default_route_table_id           = "rtb-0c24fa28bd411ba25" -> null
      - default_security_group_id        = "sg-042aa7ca49f876157" -> null
      - dhcp_options_id                  = "dopt-983cf3f2" -> null
      - enable_dns_hostnames             = true -> null
      - enable_dns_support               = true -> null
      - id                               = "vpc-04f585514ab5ec161" -> null
      - instance_tenancy                 = "default" -> null
      - ipv6_association_id              = "vpc-cidr-assoc-0352b999e17fe85cf" -> null
      - ipv6_cidr_block                  = "2a05:d014:bab:2f00::/56" -> null
      - main_route_table_id              = "rtb-0c24fa28bd411ba25" -> null
      - owner_id                         = "143440624024" -> null
      - tags                             = {
          - "Name" = "Ex. 5 VPC"
        } -> null
    }

Plan: 0 to add, 0 to change, 13 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

aws_route_table_association.rt2public: Destroying... [id=rtbassoc-0646371af14e79905]
aws_network_interface.ex5_eni: Destroying... [id=eni-08910e02f4dc4c07c]
aws_eip.ex5_eip: Destroying... [id=eipalloc-06d509fb0f3bb5078]
aws_default_security_group.def_sg: Destroying... [id=sg-042aa7ca49f876157]
aws_instance.ex5_other: Destroying... [id=i-0802bd9e2a13f4cc1]
aws_default_security_group.def_sg: Destruction complete after 0s
aws_route_table_association.rt2public: Destruction complete after 4s
aws_route_table.ex5_rt: Destroying... [id=rtb-05d0ba9924182bf02]
aws_network_interface.ex5_eni: Still destroying... [id=eni-08910e02f4dc4c07c, 10s elapsed]
aws_eip.ex5_eip: Still destroying... [id=eipalloc-06d509fb0f3bb5078, 10s elapsed]
aws_instance.ex5_other: Still destroying... [id=i-0802bd9e2a13f4cc1, 10s elapsed]
aws_route_table.ex5_rt: Still destroying... [id=rtb-05d0ba9924182bf02, 10s elapsed]
aws_network_interface.ex5_eni: Still destroying... [id=eni-08910e02f4dc4c07c, 20s elapsed]
aws_eip.ex5_eip: Still destroying... [id=eipalloc-06d509fb0f3bb5078, 20s elapsed]
aws_instance.ex5_other: Still destroying... [id=i-0802bd9e2a13f4cc1, 20s elapsed]
aws_eip.ex5_eip: Destruction complete after 20s
aws_instance.ex5_web: Destroying... [id=i-06a96d6208037a770]
aws_route_table.ex5_rt: Still destroying... [id=rtb-05d0ba9924182bf02, 20s elapsed]
aws_route_table.ex5_rt: Destruction complete after 21s
aws_network_interface.ex5_eni: Destruction complete after 25s
aws_instance.ex5_jump: Destroying... [id=i-0ac15e232945ef2f8]
aws_instance.ex5_other: Destruction complete after 28s
aws_subnet.ex5_private: Destroying... [id=subnet-05b20cf22dd103de1]
aws_instance.ex5_web: Still destroying... [id=i-06a96d6208037a770, 10s elapsed]
aws_subnet.ex5_private: Destruction complete after 5s
aws_instance.ex5_jump: Still destroying... [id=i-0ac15e232945ef2f8, 10s elapsed]
aws_instance.ex5_web: Still destroying... [id=i-06a96d6208037a770, 20s elapsed]
aws_instance.ex5_jump: Still destroying... [id=i-0ac15e232945ef2f8, 20s elapsed]
aws_instance.ex5_jump: Destruction complete after 24s
aws_instance.ex5_web: Still destroying... [id=i-06a96d6208037a770, 30s elapsed]
aws_instance.ex5_web: Destruction complete after 33s
aws_internet_gateway.ex5_igw: Destroying... [id=igw-0ef58e1d1ce3489e1]
aws_key_pair.course_ssh_key: Destroying... [id=tf-pubcloud2020]
aws_subnet.ex5_public: Destroying... [id=subnet-046c8e11ac4d61aa6]
aws_key_pair.course_ssh_key: Destruction complete after 6s
aws_internet_gateway.ex5_igw: Still destroying... [id=igw-0ef58e1d1ce3489e1, 10s elapsed]
aws_subnet.ex5_public: Still destroying... [id=subnet-046c8e11ac4d61aa6, 10s elapsed]
aws_subnet.ex5_public: Destruction complete after 14s
aws_internet_gateway.ex5_igw: Destruction complete after 19s
aws_vpc.ex5_vpc: Destroying... [id=vpc-04f585514ab5ec161]
aws_vpc.ex5_vpc: Destruction complete after 4s

Destroy complete! Resources: 13 destroyed.
```

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
