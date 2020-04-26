# Exercise 4: Deploy a Virtual Network Infrastructure

The fourth exercise is about deploying more than just one VM.
This builds on the previous exercise
by comprising a web server and SSH access to VMs.
It no longer requires use of S3 (or similar).
A new private subnet, an SSH jump host, and a third VM are added.

## Overview

The hands-on exercise has specific requirements when using AWS (or Azure).
As before, I'll be using
[AWS](https://aws.amazon.com/)
as cloud provider
and
[Terraform](https://www.terraform.io/)
as *Infrastructure-as-Code* tool.

The exercise objectives for AWS are:

1. Create a *VPN* and two *subnets* (public and private).
2. Create an *Internet Gateway* and associate it with the VPC.
3. Create a *route table* for the public subnet and add a *default route*
   pointing to the Internet Gateway.
4. Adjust the *default security group* to allow HTTP, HTTPS, and SSH
   to all virtual machines.  Use GUI if necessary.
5. (Optional) Create an *elastic IP address* and
   an *elastic network interface*.
6. Deploy a *web server* in the public subnet (use the tools you created
   in the [previous exercise](../ex3-web/) to deploy it).
7. Deploy an *SSH jump host* in the public subnet.
8. Deploy *another VM instance* in the private subnet.
9. Verify that:
   1. You can open an SSH session to the web server and jump host
      from the Internet;
   2. You can download a web page from the web server;
   3. The jump host can open an SSH session to the VM instance in the
      private subnet;
   4. The VM instance in the private subnet cannot reach destinations
      outside of your virtual network.
10. (Optional) Write an automated test suite (for example, an
   [Ansible](https://www.ansible.com/) playbook).

## Exploring the Problem Space

I have created a VPC in the
[second exercise](../ex2-iac/),
but no subnets,
no Internet Gateways,
no route tables,
and no routes.

Instead of changing the default Security Group,
I have created a new one in the [third exercise](../ex3-web/),
and have then allowed SSH, HTTP, and HTTPS there.
I did look into using the default Security Group,
but decided against doing so,
because *destroying* the Terraform deployment would not have cleaned up
the changes to the default Security Group.
This is different here,
because the default Security Group of a *new* VPC is configured.
Removing the VPC should remove its default Security Group, too.

I have not yet created an
[elastic IP address](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
(EIP) nor an
[elastic network interface](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html)
(ENI).

In the [third exercise](../ex3-web/),
I have created a web server,
i.e., Apache running on Ubuntu,
provisioned with cloud-init.

Omitting the web server of the web server setup results in an SSH jump host,
or *another* VM instance. ;-)

For most of this exercise I can build upon previous work.
The simple VPC configuration from exercise 2 needs to be extended
with additional components.
The default Security Group shall be used.
I can use Ubuntu GNU/Linux VM instances as before.
The cloud-init configuration needs to be adjusted slightly,
i.e., no S3 hosted image on the web server index page,
and the *other* VM instance in the private subnet cannot install
updated Ubuntu packages.
Thus I will just look at the new components
before writing a Terraform configuration.

### Internet Gateway

An
[AWS VPC Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
adds Internet connectivity to a VPC.
As we have seen [before](../ex3-web/),
the default VPC has Internet access,
thus it should have an Internet Gateway.
This can be confirmed using the AWS CLI:

    $ aws ec2 describe-internet-gateways
    -----------------------------------
    |    DescribeInternetGateways     |
    +---------------------------------+
    ||       InternetGateways        ||
    |+-------------------------------+|
    ||       InternetGatewayId       ||
    |+-------------------------------+|
    ||  igw-5b1fdd30                 ||
    |+-------------------------------+|
    |||         Attachments         |||
    ||+------------+----------------+||
    |||    State   |     VpcId      |||
    ||+------------+----------------+||
    |||  available |  vpc-7f13dc15  |||
    ||+------------+----------------+||
    $ aws ec2 describe-vpcs --vpc-ids vpc-7f13dc15
    --------------------------------------------------
    |                  DescribeVpcs                  |
    +------------------------------------------------+
    ||                     Vpcs                     ||
    |+-----------------------+----------------------+|
    ||  CidrBlock            |  172.31.0.0/16       ||
    ||  DhcpOptionsId        |  dopt-983cf3f2       ||
    ||  InstanceTenancy      |  default             ||
    ||  IsDefault            |  True                ||
    ||  State                |  available           ||
    ||  VpcId                |  vpc-7f13dc15        ||
    |+-----------------------+----------------------+|
    |||           CidrBlockAssociationSet          |||
    ||+----------------+---------------------------+||
    |||  AssociationId |  vpc-cidr-assoc-f576a99e  |||
    |||  CidrBlock     |  172.31.0.0/16            |||
    ||+----------------+---------------------------+||
    ||||              CidrBlockState              ||||
    |||+---------------+--------------------------+|||
    ||||  State        |  associated              ||||
    |||+---------------+--------------------------+|||

### Subnets and Route Tables

VM instances are connected to
[subnets](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html)
inside a VPC.
[Route Tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
determine packet forwarding to destinations outside the subnet.

The default VPC comprises subnets and route tables as well:

    $ aws ec2 describe-subnets
    ------------------------------------------------------
    |                   DescribeSubnets                  |
    +----------------------------------------------------+
    ||                      Subnets                     ||
    |+------------------------------+-------------------+|
    ||  AssignIpv6AddressOnCreation |  False            ||
    ||  AvailabilityZone            |  eu-central-1b    ||
    ||  AvailableIpAddressCount     |  4091             ||
    ||  CidrBlock                   |  172.31.32.0/20   ||
    ||  DefaultForAz                |  True             ||
    ||  MapPublicIpOnLaunch         |  True             ||
    ||  State                       |  available        ||
    ||  SubnetId                    |  subnet-e7d63b9b  ||
    ||  VpcId                       |  vpc-7f13dc15     ||
    |+------------------------------+-------------------+|
    ||                      Subnets                     ||
    |+------------------------------+-------------------+|
    ||  AssignIpv6AddressOnCreation |  False            ||
    ||  AvailabilityZone            |  eu-central-1c    ||
    ||  AvailableIpAddressCount     |  4091             ||
    ||  CidrBlock                   |  172.31.0.0/20    ||
    ||  DefaultForAz                |  True             ||
    ||  MapPublicIpOnLaunch         |  True             ||
    ||  State                       |  available        ||
    ||  SubnetId                    |  subnet-852cdcc9  ||
    ||  VpcId                       |  vpc-7f13dc15     ||
    |+------------------------------+-------------------+|
    ||                      Subnets                     ||
    |+------------------------------+-------------------+|
    ||  AssignIpv6AddressOnCreation |  False            ||
    ||  AvailabilityZone            |  eu-central-1a    ||
    ||  AvailableIpAddressCount     |  4091             ||
    ||  CidrBlock                   |  172.31.16.0/20   ||
    ||  DefaultForAz                |  True             ||
    ||  MapPublicIpOnLaunch         |  True             ||
    ||  State                       |  available        ||
    ||  SubnetId                    |  subnet-0207b068  ||
    ||  VpcId                       |  vpc-7f13dc15     ||
    |+------------------------------+-------------------+|
    $ aws ec2 describe-route-tables
    ----------------------------------------------------------------------------
    |                            DescribeRouteTables                           |
    +--------------------------------------------------------------------------+
    ||                               RouteTables                              ||
    |+-----------------------------------+------------------------------------+|
    ||           RouteTableId            |               VpcId                ||
    |+-----------------------------------+------------------------------------+|
    ||  rtb-4c105026                     |  vpc-7f13dc15                      ||
    |+-----------------------------------+------------------------------------+|
    |||                             Associations                             |||
    ||+---------+-------------------------------------+----------------------+||
    |||  Main   |       RouteTableAssociationId       |    RouteTableId      |||
    ||+---------+-------------------------------------+----------------------+||
    |||  True   |  rtbassoc-62f0a00f                  |  rtb-4c105026        |||
    ||+---------+-------------------------------------+----------------------+||
    |||                                Routes                                |||
    ||+-----------------------+---------------+--------------------+---------+||
    ||| DestinationCidrBlock  |   GatewayId   |      Origin        |  State  |||
    ||+-----------------------+---------------+--------------------+---------+||
    |||  172.31.0.0/16        |  local        |  CreateRouteTable  |  active |||
    |||  0.0.0.0/0            |  igw-5b1fdd30 |  CreateRoute       |  active |||
    ||+-----------------------+---------------+--------------------+---------+||

The default (*Main*) route table contains a default route
to the default Internet Gateway.
This is consistent with the observation of successful Internet connectivity
in the previous exercise. ;-)

A *private* subnet is a subnet without route to the Internet.
Since a subnet without specific route table uses the VPC's Main route table,
a route table without (default) route to the Internet needs to be created
and associated with the private subnet,
unless the VPC does not have a Main route table,
or the Main route table does not point to an Internet Gateway.

The subnet model behind this exercise seems to be based
on a VPC without Internet access in the Main route table.
Thus any subnet of this VPC is private by default
and needs to be explicitly configured for Internet access.
This seems to be more secure than requiring to add configuration
to inhibit Internet access.

Many route tables can be created and attached to different objects inside a VPC,
thus allowing for some kind of *Policy Based Routing*.
The use of a special route table for Internet access
is an instance of the Policy Based Routing idea.

### Elastic IP Address

An
[Elastic IP Address](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
(EIP) represents one IPv4 address
that can be associated with an EC2 instance.
By default,
each AWS account is limited to 5 EIPs.
As long as an EIP is associated with a running EC2 instance,
it does not incur extra costs.
EIPs not associated to any instance,
or to an inactive instance,
do incur extra costs.

There are no EIPs allocated to an AWS account by default:

    $ aws ec2 describe-addresses
    -------------------
    |DescribeAddresses|
    +-----------------+

### Elastic Network Interface

An
[Elastic Network Interface](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html)
(ENI) shows some similarity to an EIP,
because it allows an IP address to move from one instance to another.
But it does not give you a more or less *global* IPv4 address,
but rather IPv4 and / or IPv6 addresses inside a VPC.

There are no ENIs available by default without an EC2 instance:

    $ aws ec2 describe-network-interfaces
    ---------------------------
    |DescribeNetworkInterfaces|
    +-------------------------+

## Terraform

I write a straight-forward
[Terraform configuration file](terraform/vni.tf)
for this exercise.
It is based on the previous solutions
for hand-on exercises two and three.

All variables have default values,
thus I do not need to specify any variables
to `apply` the configuration.

The new resources needed for this exercise
are all quite simple to understand
(for some one with networking background).
Thus I just open the
[Terraform documentation](https://www.terraform.io/docs/configuration/index.html),
select the
[AWS provider](https://www.terraform.io/docs/providers/aws/index.html)
section,
and select the respective resource documentation by name.
The only surprise for me was the need for an additional
[aws\_route\_table\_association](https://www.terraform.io/docs/providers/aws/r/route_table_association.html)
resource to bind the route table to the public subnet.

The EC2 instances require a few adjustments:
specifying the correct subnet via `subnet_id`,
no S3 dependencies,
no specific Security Group,
public IP address assignment accroding to selected subnet,
and instance specific cloud-config file as `user-data`.

The Terraform
[AWS IGW](https://www.terraform.io/docs/providers/aws/r/internet_gateway.html)
documentation suggests to add an explicit dependency on the IGW
to EC2 instances and Elastic IP addresses.
This seems reasonable,
because without the Internet gateway
the new instance cannot, e.g., install package updates.
Thus I add this dependency to both web server and jump host,
but not the isolated additional VM.

For the moment,
I omit the optional EIP and ENI parts of the exercise.

After using `terraform fmt` to format the Terraform configuration file,
I initialize the Terraform working directory with `terraform init`:

```
$ terraform fmt
vni.tf
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

Before trying to apply the configuration,
I validate it using `terraform validate`:

```
$ terraform validate
Success! The configuration is valid.

```

Since the configuration successfully validates,
I can use `terraform apply`.
This will present me with the planned changes
and require confirmation before implementing them.

But first I want to try out `terraform graph`.
This can be used to generate different graphs
for different operations.

First I want to see the graph for the *plan*.
This is the default graph generated for a directory
containing a Terraform configuration:

    terraform graph | dot -Tsvg > the_plan.svg

This results in the following image:

![Terraform plan graph](terraform/the_plan.svg)

Next I want take a look at the *apply* graph:

    terraform graph -type apply | dot -Tsvg > apply.svg

The image looks as follows:

![Terraform apply graph](terraform/apply.svg)

Then I go ahead and use `terraform apply`:

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
              + description      = "Allow Internet access for, e.g., updates"
              + from_port        = 0
              + ipv6_cidr_blocks = []
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
              + description      = "Allow HTTP from the Internet"
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
              + description      = "Allow HTTPS from the Internet"
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
              + description      = "Allow SSH from the Internet"
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
          + "Name" = "Ex. 4 default Security Group"
        }
      + vpc_id                 = (known after apply)
    }

  # aws_instance.ex4_jump will be created
  + resource "aws_instance" "ex4_jump" {
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
          + "Name" = "Ex. 4 jump host"
        }
      + tenancy                      = (known after apply)
      + user_data                    = "9ed191a9e90b29779765efa9828c23574c1d97a7"
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

  # aws_instance.ex4_other will be created
  + resource "aws_instance" "ex4_other" {
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
          + "Name" = "Ex. 4 private host"
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

  # aws_instance.ex4_web will be created
  + resource "aws_instance" "ex4_web" {
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
          + "Name" = "Ex. 4 web server"
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

  # aws_internet_gateway.ex4_igw will be created
  + resource "aws_internet_gateway" "ex4_igw" {
      + id       = (known after apply)
      + owner_id = (known after apply)
      + tags     = {
          + "Name" = "Ex. 4 Internet gateway"
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

  # aws_route_table.ex4_rt will be created
  + resource "aws_route_table" "ex4_rt" {
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
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
          + "Name" = "Ex. 4 route table for Internet access"
        }
      + vpc_id           = (known after apply)
    }

  # aws_route_table_association.rt2public will be created
  + resource "aws_route_table_association" "rt2public" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_subnet.ex4_private will be created
  + resource "aws_subnet" "ex4_private" {
      + arn                             = (known after apply)
      + assign_ipv6_address_on_creation = false
      + availability_zone               = (known after apply)
      + availability_zone_id            = (known after apply)
      + cidr_block                      = "10.42.0.0/24"
      + id                              = (known after apply)
      + ipv6_cidr_block                 = (known after apply)
      + ipv6_cidr_block_association_id  = (known after apply)
      + map_public_ip_on_launch         = false
      + owner_id                        = (known after apply)
      + tags                            = {
          + "Name" = "Ex. 4 private subnet"
        }
      + vpc_id                          = (known after apply)
    }

  # aws_subnet.ex4_public will be created
  + resource "aws_subnet" "ex4_public" {
      + arn                             = (known after apply)
      + assign_ipv6_address_on_creation = false
      + availability_zone               = (known after apply)
      + availability_zone_id            = (known after apply)
      + cidr_block                      = "10.42.255.0/24"
      + id                              = (known after apply)
      + ipv6_cidr_block                 = (known after apply)
      + ipv6_cidr_block_association_id  = (known after apply)
      + map_public_ip_on_launch         = true
      + owner_id                        = (known after apply)
      + tags                            = {
          + "Name" = "Ex. 4 public subnet"
        }
      + vpc_id                          = (known after apply)
    }

  # aws_vpc.ex4_vpc will be created
  + resource "aws_vpc" "ex4_vpc" {
      + arn                              = (known after apply)
      + assign_generated_ipv6_cidr_block = false
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
          + "Name" = "Ex. 4 VPC"
        }
    }

Plan: 11 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_key_pair.course_ssh_key: Creating...
aws_vpc.ex4_vpc: Creating...
aws_key_pair.course_ssh_key: Creation complete after 1s [id=tf-pubcloud2020]
aws_vpc.ex4_vpc: Creation complete after 7s [id=vpc-0b508a704edb473cb]
aws_internet_gateway.ex4_igw: Creating...
aws_subnet.ex4_private: Creating...
aws_subnet.ex4_public: Creating...
aws_default_security_group.def_sg: Creating...
aws_subnet.ex4_private: Creation complete after 3s [id=subnet-02521eb45700f5398]
aws_instance.ex4_other: Creating...
aws_subnet.ex4_public: Creation complete after 3s [id=subnet-07a2d8e446b100c58]
aws_internet_gateway.ex4_igw: Creation complete after 4s [id=igw-0f441755d966d38af]
aws_route_table.ex4_rt: Creating...
aws_instance.ex4_web: Creating...
aws_instance.ex4_jump: Creating...
aws_default_security_group.def_sg: Creation complete after 5s [id=sg-084a86c98ad8c2128]
aws_route_table.ex4_rt: Creation complete after 2s [id=rtb-0667e7f44e185c197]
aws_route_table_association.rt2public: Creating...
aws_route_table_association.rt2public: Creation complete after 0s [id=rtbassoc-03399492da585a8f6]
aws_instance.ex4_other: Still creating... [10s elapsed]
aws_instance.ex4_web: Still creating... [10s elapsed]
aws_instance.ex4_jump: Still creating... [10s elapsed]
aws_instance.ex4_other: Still creating... [20s elapsed]
aws_instance.ex4_web: Still creating... [20s elapsed]
aws_instance.ex4_jump: Still creating... [20s elapsed]
aws_instance.ex4_other: Still creating... [30s elapsed]
aws_instance.ex4_web: Still creating... [30s elapsed]
aws_instance.ex4_jump: Still creating... [30s elapsed]
aws_instance.ex4_other: Creation complete after 33s [id=i-027f0cb1638fd711c]
aws_instance.ex4_jump: Creation complete after 32s [id=i-0e2bdac3c56bd21e5]
aws_instance.ex4_web: Still creating... [40s elapsed]
aws_instance.ex4_web: Creation complete after 48s [id=i-023b492515018c825]

Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

VPC_prefix = 10.42.0.0/16
jump_host_ip = 18.185.67.143
jump_host_name = ec2-18-185-67-143.eu-central-1.compute.amazonaws.com
private_host_ip = 10.42.255.147
private_host_name = ip-10-42-255-147.eu-central-1.compute.internal
private_subnet_prefix = 10.42.0.0/24
public_subnet_prefix = 10.42.255.0/24
web_server_ip = 54.93.244.69
web_server_name = ec2-54-93-244-69.eu-central-1.compute.amazonaws.com
```

That looks promising.
Let's find out what happened. ;-)

*Spoiler:
I messed up the output definitions for the other VM in the private subnet.*

Terraform can `show` the deployment:

```
$ terraform show
# aws_default_security_group.def_sg:
resource "aws_default_security_group" "def_sg" {
    arn                    = "arn:aws:ec2:eu-central-1:143440624024:security-group/sg-084a86c98ad8c2128"
    description            = "default VPC security group"
    egress                 = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = "Allow Internet access for, e.g., updates"
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
    id                     = "sg-084a86c98ad8c2128"
    ingress                = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = "Allow HTTP from the Internet"
            from_port        = 80
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 80
        },
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = "Allow HTTPS from the Internet"
            from_port        = 443
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 443
        },
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = "Allow SSH from the Internet"
            from_port        = 22
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 22
        },
        {
            cidr_blocks      = []
            description      = "Allow everything inside the SG"
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = true
            to_port          = 0
        },
    ]
    name                   = "default"
    owner_id               = "143440624024"
    revoke_rules_on_delete = false
    tags                   = {
        "Name" = "Ex. 4 default Security Group"
    }
    vpc_id                 = "vpc-0b508a704edb473cb"
}

# aws_instance.ex4_jump:
resource "aws_instance" "ex4_jump" {
    ami                          = "ami-0e342d72b12109f91"
    arn                          = "arn:aws:ec2:eu-central-1:143440624024:instance/i-0e2bdac3c56bd21e5"
    associate_public_ip_address  = true
    availability_zone            = "eu-central-1a"
    cpu_core_count               = 1
    cpu_threads_per_core         = 1
    disable_api_termination      = false
    ebs_optimized                = false
    get_password_data            = false
    hibernation                  = false
    id                           = "i-0e2bdac3c56bd21e5"
    instance_state               = "running"
    instance_type                = "t2.micro"
    ipv6_address_count           = 0
    ipv6_addresses               = []
    key_name                     = "tf-pubcloud2020"
    monitoring                   = false
    primary_network_interface_id = "eni-042766ede1486ffdb"
    private_dns                  = "ip-10-42-255-147.eu-central-1.compute.internal"
    private_ip                   = "10.42.255.147"
    public_dns                   = "ec2-18-185-67-143.eu-central-1.compute.amazonaws.com"
    public_ip                    = "18.185.67.143"
    security_groups              = []
    source_dest_check            = true
    subnet_id                    = "subnet-07a2d8e446b100c58"
    tags                         = {
        "Name" = "Ex. 4 jump host"
    }
    tenancy                      = "default"
    user_data                    = "9ed191a9e90b29779765efa9828c23574c1d97a7"
    volume_tags                  = {}
    vpc_security_group_ids       = [
        "sg-084a86c98ad8c2128",
    ]

    credit_specification {
        cpu_credits = "standard"
    }

    root_block_device {
        delete_on_termination = true
        encrypted             = false
        iops                  = 100
        volume_id             = "vol-07f92581bbad1b864"
        volume_size           = 8
        volume_type           = "gp2"
    }
}

# aws_instance.ex4_other:
resource "aws_instance" "ex4_other" {
    ami                          = "ami-0e342d72b12109f91"
    arn                          = "arn:aws:ec2:eu-central-1:143440624024:instance/i-027f0cb1638fd711c"
    associate_public_ip_address  = false
    availability_zone            = "eu-central-1c"
    cpu_core_count               = 1
    cpu_threads_per_core         = 1
    disable_api_termination      = false
    ebs_optimized                = false
    get_password_data            = false
    hibernation                  = false
    id                           = "i-027f0cb1638fd711c"
    instance_state               = "running"
    instance_type                = "t2.micro"
    ipv6_address_count           = 0
    ipv6_addresses               = []
    key_name                     = "tf-pubcloud2020"
    monitoring                   = false
    primary_network_interface_id = "eni-005036578823f5482"
    private_dns                  = "ip-10-42-0-143.eu-central-1.compute.internal"
    private_ip                   = "10.42.0.143"
    security_groups              = []
    source_dest_check            = true
    subnet_id                    = "subnet-02521eb45700f5398"
    tags                         = {
        "Name" = "Ex. 4 private host"
    }
    tenancy                      = "default"
    user_data                    = "455b01c87a20b41630a012c794e4d53d8cda1d75"
    volume_tags                  = {}
    vpc_security_group_ids       = [
        "sg-084a86c98ad8c2128",
    ]

    credit_specification {
        cpu_credits = "standard"
    }

    root_block_device {
        delete_on_termination = true
        encrypted             = false
        iops                  = 100
        volume_id             = "vol-04c5697e3ac46667b"
        volume_size           = 8
        volume_type           = "gp2"
    }
}

# aws_instance.ex4_web:
resource "aws_instance" "ex4_web" {
    ami                          = "ami-0e342d72b12109f91"
    arn                          = "arn:aws:ec2:eu-central-1:143440624024:instance/i-023b492515018c825"
    associate_public_ip_address  = true
    availability_zone            = "eu-central-1a"
    cpu_core_count               = 1
    cpu_threads_per_core         = 1
    disable_api_termination      = false
    ebs_optimized                = false
    get_password_data            = false
    hibernation                  = false
    id                           = "i-023b492515018c825"
    instance_state               = "running"
    instance_type                = "t2.micro"
    ipv6_address_count           = 0
    ipv6_addresses               = []
    key_name                     = "tf-pubcloud2020"
    monitoring                   = false
    primary_network_interface_id = "eni-0b0c13a8df17bd2ad"
    private_dns                  = "ip-10-42-255-153.eu-central-1.compute.internal"
    private_ip                   = "10.42.255.153"
    public_dns                   = "ec2-54-93-244-69.eu-central-1.compute.amazonaws.com"
    public_ip                    = "54.93.244.69"
    security_groups              = []
    source_dest_check            = true
    subnet_id                    = "subnet-07a2d8e446b100c58"
    tags                         = {
        "Name" = "Ex. 4 web server"
    }
    tenancy                      = "default"
    user_data                    = "6197aaec194f10c08caf60960ec297a41f695ad2"
    volume_tags                  = {}
    vpc_security_group_ids       = [
        "sg-084a86c98ad8c2128",
    ]

    credit_specification {
        cpu_credits = "standard"
    }

    root_block_device {
        delete_on_termination = true
        encrypted             = false
        iops                  = 100
        volume_id             = "vol-0bd92088d60c8dceb"
        volume_size           = 8
        volume_type           = "gp2"
    }
}

# aws_internet_gateway.ex4_igw:
resource "aws_internet_gateway" "ex4_igw" {
    id       = "igw-0f441755d966d38af"
    owner_id = "143440624024"
    tags     = {
        "Name" = "Ex. 4 Internet gateway"
    }
    vpc_id   = "vpc-0b508a704edb473cb"
}

# aws_key_pair.course_ssh_key:
resource "aws_key_pair" "course_ssh_key" {
    fingerprint = "bc:c0:ba:de:c1:2d:a8:38:5d:08:33:ba:dd:18:db:c4"
    id          = "tf-pubcloud2020"
    key_name    = "tf-pubcloud2020"
    key_pair_id = "key-04b1f0783a9f3db00"
    public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDiXuVGxn6zqLCPKbcojNC813FAnOPBWToBz/XTQaMzMsoAeKMRwVrUoyHEVj8UTFiuEUbTz/0jHItv5ZmFXI1DNY1m+hXxCDVcBp8ojCutX3+AJ012qG2PIZaloaYCjrTkhHj9VmMHAl1jzJ0EbPsoU/Qc4pZCNUNaCVCkG6EHisOUy9wx20i4gA/nrDnjIxk9TD2mGdlVCK7SESH/vGWgMtU6fLI65trtC4eojPNNUyMq8tTLyJxoTdYEwMY5alKkcjjw6+yVBOrtYgZSlMW02WLTkJT7eCxwVHig8a+bywiwAxuvYlUgfmOHEGEIXXTGk/+KNiLrDXdmkK4kuUvlf6rD7qR/kedqQAt0k5v/PiW3ufpej7n1ZBZroSsBT/0Yp5UcCLxpzskUYu+TRLRp+6gI50KsNe/oT8tesNtOVTK2ePD4eXApXAYwQpXy1389c4gGgh4wWljmHyeoFjcd4Soq847/PNspRdswR/u5jyswTsCROKsCJ4+whJRme8JoqaZHGBTpTu9n6gaZJVXbFM/55RYh0bpuCD5BHrdk0+HX4BmhJ1KqdDTDR84y2riwlpv6Eiw8AX8N2GVLOpP6RMt/AUCNUEy5nPWJosKb+UQE/j1dRJ9iorm2EGbh30dv/nRCb2Cu7BVyNWbmSrVaKdJub28SfV5L51sd+ATBw== auerswald@short"
}

# aws_route_table.ex4_rt:
resource "aws_route_table" "ex4_rt" {
    id               = "rtb-0667e7f44e185c197"
    owner_id         = "143440624024"
    propagating_vgws = []
    route            = [
        {
            cidr_block                = "0.0.0.0/0"
            egress_only_gateway_id    = ""
            gateway_id                = "igw-0f441755d966d38af"
            instance_id               = ""
            ipv6_cidr_block           = ""
            nat_gateway_id            = ""
            network_interface_id      = ""
            transit_gateway_id        = ""
            vpc_peering_connection_id = ""
        },
    ]
    tags             = {
        "Name" = "Ex. 4 route table for Internet access"
    }
    vpc_id           = "vpc-0b508a704edb473cb"
}

# aws_route_table_association.rt2public:
resource "aws_route_table_association" "rt2public" {
    id             = "rtbassoc-03399492da585a8f6"
    route_table_id = "rtb-0667e7f44e185c197"
    subnet_id      = "subnet-07a2d8e446b100c58"
}

# aws_subnet.ex4_private:
resource "aws_subnet" "ex4_private" {
    arn                             = "arn:aws:ec2:eu-central-1:143440624024:subnet/subnet-02521eb45700f5398"
    assign_ipv6_address_on_creation = false
    availability_zone               = "eu-central-1c"
    availability_zone_id            = "euc1-az1"
    cidr_block                      = "10.42.0.0/24"
    id                              = "subnet-02521eb45700f5398"
    map_public_ip_on_launch         = false
    owner_id                        = "143440624024"
    tags                            = {
        "Name" = "Ex. 4 private subnet"
    }
    vpc_id                          = "vpc-0b508a704edb473cb"
}

# aws_subnet.ex4_public:
resource "aws_subnet" "ex4_public" {
    arn                             = "arn:aws:ec2:eu-central-1:143440624024:subnet/subnet-07a2d8e446b100c58"
    assign_ipv6_address_on_creation = false
    availability_zone               = "eu-central-1a"
    availability_zone_id            = "euc1-az2"
    cidr_block                      = "10.42.255.0/24"
    id                              = "subnet-07a2d8e446b100c58"
    map_public_ip_on_launch         = true
    owner_id                        = "143440624024"
    tags                            = {
        "Name" = "Ex. 4 public subnet"
    }
    vpc_id                          = "vpc-0b508a704edb473cb"
}

# aws_vpc.ex4_vpc:
resource "aws_vpc" "ex4_vpc" {
    arn                              = "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-0b508a704edb473cb"
    assign_generated_ipv6_cidr_block = false
    cidr_block                       = "10.42.0.0/16"
    default_network_acl_id           = "acl-09e1365852f2f4dfd"
    default_route_table_id           = "rtb-0322e2794276fc538"
    default_security_group_id        = "sg-084a86c98ad8c2128"
    dhcp_options_id                  = "dopt-983cf3f2"
    enable_dns_hostnames             = true
    enable_dns_support               = true
    id                               = "vpc-0b508a704edb473cb"
    instance_tenancy                 = "default"
    main_route_table_id              = "rtb-0322e2794276fc538"
    owner_id                         = "143440624024"
    tags                             = {
        "Name" = "Ex. 4 VPC"
    }
}

# data.aws_ami.gnu_linux_image:
data "aws_ami" "gnu_linux_image" {
    architecture          = "x86_64"
    block_device_mappings = [
        {
            device_name  = "/dev/sda1"
            ebs          = {
                "delete_on_termination" = "true"
                "encrypted"             = "false"
                "iops"                  = "0"
                "snapshot_id"           = "snap-04380c2d33633ce33"
                "volume_size"           = "8"
                "volume_type"           = "gp2"
            }
            no_device    = ""
            virtual_name = ""
        },
        {
            device_name  = "/dev/sdb"
            ebs          = {}
            no_device    = ""
            virtual_name = "ephemeral0"
        },
        {
            device_name  = "/dev/sdc"
            ebs          = {}
            no_device    = ""
            virtual_name = "ephemeral1"
        },
    ]
    creation_date         = "2020-04-09T16:44:38.000Z"
    description           = "Canonical, Ubuntu, 18.04 LTS, amd64 bionic image build on 2020-04-08"
    hypervisor            = "xen"
    id                    = "ami-0e342d72b12109f91"
    image_id              = "ami-0e342d72b12109f91"
    image_location        = "099720109477/ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20200408"
    image_type            = "machine"
    most_recent           = true
    name                  = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20200408"
    owner_id              = "099720109477"
    owners                = [
        "099720109477",
    ]
    product_codes         = []
    public                = true
    root_device_name      = "/dev/sda1"
    root_device_type      = "ebs"
    root_snapshot_id      = "snap-04380c2d33633ce33"
    sriov_net_support     = "simple"
    state                 = "available"
    state_reason          = {
        "code"    = "UNSET"
        "message" = "UNSET"
    }
    tags                  = {}
    virtualization_type   = "hvm"

    filter {
        name   = "name"
        values = [
            "ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-server-????????",
        ]
    }
    filter {
        name   = "state"
        values = [
            "available",
        ]
    }
}


Outputs:

VPC_prefix = "10.42.0.0/16"
jump_host_ip = "18.185.67.143"
jump_host_name = "ec2-18-185-67-143.eu-central-1.compute.amazonaws.com"
private_host_ip = "10.42.255.147"
private_host_name = "ip-10-42-255-147.eu-central-1.compute.internal"
private_subnet_prefix = "10.42.0.0/24"
public_subnet_prefix = "10.42.255.0/24"
web_server_ip = "54.93.244.69"
web_server_name = "ec2-54-93-244-69.eu-central-1.compute.amazonaws.com"
```

The AWS CLI should show additional objects as well:

```
$ aws ec2 describe-vpcs --filter Name=isDefault,Values=false
-----------------------------------------------------------
|                      DescribeVpcs                       |
+---------------------------------------------------------+
||                         Vpcs                          ||
|+-----------------------+-------------------------------+|
||  CidrBlock            |  10.42.0.0/16                 ||
||  DhcpOptionsId        |  dopt-983cf3f2                ||
||  InstanceTenancy      |  default                      ||
||  IsDefault            |  False                        ||
||  State                |  available                    ||
||  VpcId                |  vpc-0b508a704edb473cb        ||
|+-----------------------+-------------------------------+|
|||               CidrBlockAssociationSet               |||
||+----------------+------------------------------------+||
|||  AssociationId |  vpc-cidr-assoc-0e2196c2c96d0f3a0  |||
|||  CidrBlock     |  10.42.0.0/16                      |||
||+----------------+------------------------------------+||
||||                  CidrBlockState                   ||||
|||+-------------------+-------------------------------+|||
||||  State            |  associated                   ||||
|||+-------------------+-------------------------------+|||
|||                        Tags                         |||
||+--------------------+--------------------------------+||
|||  Key               |  Name                          |||
|||  Value             |  Ex. 4 VPC                     |||
||+--------------------+--------------------------------+||
$ aws ec2 describe-subnets --filter Name=vpc-id,Values=vpc-0b508a704edb473cb
---------------------------------------------------------------
|                       DescribeSubnets                       |
+-------------------------------------------------------------+
||                          Subnets                          ||
|+------------------------------+----------------------------+|
||  AssignIpv6AddressOnCreation |  False                     ||
||  AvailabilityZone            |  eu-central-1c             ||
||  AvailableIpAddressCount     |  250                       ||
||  CidrBlock                   |  10.42.0.0/24              ||
||  DefaultForAz                |  False                     ||
||  MapPublicIpOnLaunch         |  False                     ||
||  State                       |  available                 ||
||  SubnetId                    |  subnet-02521eb45700f5398  ||
||  VpcId                       |  vpc-0b508a704edb473cb     ||
|+------------------------------+----------------------------+|
|||                          Tags                           |||
||+--------------+------------------------------------------+||
|||  Key         |  Name                                    |||
|||  Value       |  Ex. 4 private subnet                    |||
||+--------------+------------------------------------------+||
||                          Subnets                          ||
|+------------------------------+----------------------------+|
||  AssignIpv6AddressOnCreation |  False                     ||
||  AvailabilityZone            |  eu-central-1a             ||
||  AvailableIpAddressCount     |  249                       ||
||  CidrBlock                   |  10.42.255.0/24            ||
||  DefaultForAz                |  False                     ||
||  MapPublicIpOnLaunch         |  True                      ||
||  State                       |  available                 ||
||  SubnetId                    |  subnet-07a2d8e446b100c58  ||
||  VpcId                       |  vpc-0b508a704edb473cb     ||
|+------------------------------+----------------------------+|
|||                          Tags                           |||
||+---------------+-----------------------------------------+||
|||  Key          |  Name                                   |||
|||  Value        |  Ex. 4 public subnet                    |||
||+---------------+-----------------------------------------+||
$ aws ec2 describe-internet-gateways --filter Name=attachment.vpc-id,Values=vpc-0b508a704edb473cb
--------------------------------------------
|         DescribeInternetGateways         |
+------------------------------------------+
||            InternetGateways            ||
|+----------------------------------------+|
||            InternetGatewayId           ||
|+----------------------------------------+|
||  igw-0f441755d966d38af                 ||
|+----------------------------------------+|
|||              Attachments             |||
||+------------+-------------------------+||
|||    State   |          VpcId          |||
||+------------+-------------------------+||
|||  available |  vpc-0b508a704edb473cb  |||
||+------------+-------------------------+||
|||                 Tags                 |||
||+-------+------------------------------+||
|||  Key  |            Value             |||
||+-------+------------------------------+||
|||  Name |  Ex. 4 Internet gateway      |||
||+-------+------------------------------+||
$ aws ec2 describe-route-tables --filter Name=vpc-id,Values=vpc-0b508a704edb473cb
-------------------------------------------------------------------------------------
|                                DescribeRouteTables                                |
+-----------------------------------------------------------------------------------+
||                                   RouteTables                                   ||
|+------------------------------+--------------------------------------------------+|
||  RouteTableId                |  rtb-0322e2794276fc538                           ||
||  VpcId                       |  vpc-0b508a704edb473cb                           ||
|+------------------------------+--------------------------------------------------+|
|||                                 Associations                                  |||
||+------------------------------------+------------------------------------------+||
|||  Main                              |  True                                    |||
|||  RouteTableAssociationId           |  rtbassoc-0216fffa2d6ff036e              |||
|||  RouteTableId                      |  rtb-0322e2794276fc538                   |||
||+------------------------------------+------------------------------------------+||
|||                                    Routes                                     |||
||+------------------------------------------+------------------------------------+||
|||  DestinationCidrBlock                    |  10.42.0.0/16                      |||
|||  GatewayId                               |  local                             |||
|||  Origin                                  |  CreateRouteTable                  |||
|||  State                                   |  active                            |||
||+------------------------------------------+------------------------------------+||
||                                   RouteTables                                   ||
|+------------------------------+--------------------------------------------------+|
||  RouteTableId                |  rtb-0667e7f44e185c197                           ||
||  VpcId                       |  vpc-0b508a704edb473cb                           ||
|+------------------------------+--------------------------------------------------+|
|||                                 Associations                                  |||
||+------------------------------------+------------------------------------------+||
|||  Main                              |  False                                   |||
|||  RouteTableAssociationId           |  rtbassoc-03399492da585a8f6              |||
|||  RouteTableId                      |  rtb-0667e7f44e185c197                   |||
|||  SubnetId                          |  subnet-07a2d8e446b100c58                |||
||+------------------------------------+------------------------------------------+||
|||                                    Routes                                     |||
||+----------------------+-------------------------+--------------------+---------+||
||| DestinationCidrBlock |        GatewayId        |      Origin        |  State  |||
||+----------------------+-------------------------+--------------------+---------+||
|||  10.42.0.0/16        |  local                  |  CreateRouteTable  |  active |||
|||  0.0.0.0/0           |  igw-0f441755d966d38af  |  CreateRoute       |  active |||
||+----------------------+-------------------------+--------------------+---------+||
|||                                     Tags                                      |||
||+-------------+-----------------------------------------------------------------+||
|||  Key        |  Name                                                           |||
|||  Value      |  Ex. 4 route table for Internet access                          |||
||+-------------+-----------------------------------------------------------------+||
$ aws ec2 describe-instances
---------------------------------------------------------------------------------------
|                                  DescribeInstances                                  |
+-------------------------------------------------------------------------------------+
||                                   Reservations                                    ||
|+----------------------------------+------------------------------------------------+|
||  OwnerId                         |  143440624024                                  ||
||  ReservationId                   |  r-08063a964a8fbdc26                           ||
|+----------------------------------+------------------------------------------------+|
|||                                    Instances                                    |||
||+------------------------+--------------------------------------------------------+||
|||  AmiLaunchIndex        |  0                                                     |||
|||  Architecture          |  x86_64                                                |||
|||  ClientToken           |                                                        |||
|||  EbsOptimized          |  False                                                 |||
|||  EnaSupport            |  True                                                  |||
|||  Hypervisor            |  xen                                                   |||
|||  ImageId               |  ami-0e342d72b12109f91                                 |||
|||  InstanceId            |  i-0e2bdac3c56bd21e5                                   |||
|||  InstanceType          |  t2.micro                                              |||
|||  KeyName               |  tf-pubcloud2020                                       |||
|||  LaunchTime            |  2020-04-26T14:25:05.000Z                              |||
|||  PrivateDnsName        |  ip-10-42-255-147.eu-central-1.compute.internal        |||
|||  PrivateIpAddress      |  10.42.255.147                                         |||
|||  PublicDnsName         |  ec2-18-185-67-143.eu-central-1.compute.amazonaws.com  |||
|||  PublicIpAddress       |  18.185.67.143                                         |||
|||  RootDeviceName        |  /dev/sda1                                             |||
|||  RootDeviceType        |  ebs                                                   |||
|||  SourceDestCheck       |  True                                                  |||
|||  StateTransitionReason |                                                        |||
|||  SubnetId              |  subnet-07a2d8e446b100c58                              |||
|||  VirtualizationType    |  hvm                                                   |||
|||  VpcId                 |  vpc-0b508a704edb473cb                                 |||
||+------------------------+--------------------------------------------------------+||
||||                              BlockDeviceMappings                              ||||
|||+----------------------------------------+--------------------------------------+|||
||||  DeviceName                            |  /dev/sda1                           ||||
|||+----------------------------------------+--------------------------------------+|||
|||||                                     Ebs                                     |||||
||||+----------------------------------+------------------------------------------+||||
|||||  AttachTime                      |  2020-04-26T14:25:06.000Z                |||||
|||||  DeleteOnTermination             |  True                                    |||||
|||||  Status                          |  attached                                |||||
|||||  VolumeId                        |  vol-07f92581bbad1b864                   |||||
||||+----------------------------------+------------------------------------------+||||
||||                                  Monitoring                                   ||||
|||+---------------------------------+---------------------------------------------+|||
||||  State                          |  disabled                                   ||||
|||+---------------------------------+---------------------------------------------+|||
||||                               NetworkInterfaces                               ||||
|||+-----------------------+-------------------------------------------------------+|||
||||  Description          |                                                       ||||
||||  MacAddress           |  02:c8:4a:c6:fa:9c                                    ||||
||||  NetworkInterfaceId   |  eni-042766ede1486ffdb                                ||||
||||  OwnerId              |  143440624024                                         ||||
||||  PrivateDnsName       |  ip-10-42-255-147.eu-central-1.compute.internal       ||||
||||  PrivateIpAddress     |  10.42.255.147                                        ||||
||||  SourceDestCheck      |  True                                                 ||||
||||  Status               |  in-use                                               ||||
||||  SubnetId             |  subnet-07a2d8e446b100c58                             ||||
||||  VpcId                |  vpc-0b508a704edb473cb                                ||||
|||+-----------------------+-------------------------------------------------------+|||
|||||                                 Association                                 |||||
||||+----------------+------------------------------------------------------------+||||
|||||  IpOwnerId     |  amazon                                                    |||||
|||||  PublicDnsName |  ec2-18-185-67-143.eu-central-1.compute.amazonaws.com      |||||
|||||  PublicIp      |  18.185.67.143                                             |||||
||||+----------------+------------------------------------------------------------+||||
|||||                                 Attachment                                  |||||
||||+-------------------------------+---------------------------------------------+||||
|||||  AttachTime                   |  2020-04-26T14:25:05.000Z                   |||||
|||||  AttachmentId                 |  eni-attach-01dce03cd5a345c49               |||||
|||||  DeleteOnTermination          |  True                                       |||||
|||||  DeviceIndex                  |  0                                          |||||
|||||  Status                       |  attached                                   |||||
||||+-------------------------------+---------------------------------------------+||||
|||||                                   Groups                                    |||||
||||+--------------------------+--------------------------------------------------+||||
|||||  GroupId                 |  sg-084a86c98ad8c2128                            |||||
|||||  GroupName               |  default                                         |||||
||||+--------------------------+--------------------------------------------------+||||
|||||                             PrivateIpAddresses                              |||||
||||+---------------------+-------------------------------------------------------+||||
|||||  Primary            |  True                                                 |||||
|||||  PrivateDnsName     |  ip-10-42-255-147.eu-central-1.compute.internal       |||||
|||||  PrivateIpAddress   |  10.42.255.147                                        |||||
||||+---------------------+-------------------------------------------------------+||||
||||||                                Association                                ||||||
|||||+----------------+----------------------------------------------------------+|||||
||||||  IpOwnerId     |  amazon                                                  ||||||
||||||  PublicDnsName |  ec2-18-185-67-143.eu-central-1.compute.amazonaws.com    ||||||
||||||  PublicIp      |  18.185.67.143                                           ||||||
|||||+----------------+----------------------------------------------------------+|||||
||||                                   Placement                                   ||||
|||+------------------------------------------+------------------------------------+|||
||||  AvailabilityZone                        |  eu-central-1a                     ||||
||||  GroupName                               |                                    ||||
||||  Tenancy                                 |  default                           ||||
|||+------------------------------------------+------------------------------------+|||
||||                                SecurityGroups                                 ||||
|||+--------------------------+----------------------------------------------------+|||
||||  GroupId                 |  sg-084a86c98ad8c2128                              ||||
||||  GroupName               |  default                                           ||||
|||+--------------------------+----------------------------------------------------+|||
||||                                     State                                     ||||
|||+--------------------------------+----------------------------------------------+|||
||||  Code                          |  16                                          ||||
||||  Name                          |  running                                     ||||
|||+--------------------------------+----------------------------------------------+|||
||||                                     Tags                                      ||||
|||+------------------------+------------------------------------------------------+|||
||||  Key                   |  Name                                                ||||
||||  Value                 |  Ex. 4 jump host                                     ||||
|||+------------------------+------------------------------------------------------+|||
||                                   Reservations                                    ||
|+----------------------------------+------------------------------------------------+|
||  OwnerId                         |  143440624024                                  ||
||  ReservationId                   |  r-0b257df7cd51e1258                           ||
|+----------------------------------+------------------------------------------------+|
|||                                    Instances                                    |||
||+------------------------+--------------------------------------------------------+||
|||  AmiLaunchIndex        |  0                                                     |||
|||  Architecture          |  x86_64                                                |||
|||  ClientToken           |                                                        |||
|||  EbsOptimized          |  False                                                 |||
|||  EnaSupport            |  True                                                  |||
|||  Hypervisor            |  xen                                                   |||
|||  ImageId               |  ami-0e342d72b12109f91                                 |||
|||  InstanceId            |  i-023b492515018c825                                   |||
|||  InstanceType          |  t2.micro                                              |||
|||  KeyName               |  tf-pubcloud2020                                       |||
|||  LaunchTime            |  2020-04-26T14:25:05.000Z                              |||
|||  PrivateDnsName        |  ip-10-42-255-153.eu-central-1.compute.internal        |||
|||  PrivateIpAddress      |  10.42.255.153                                         |||
|||  PublicDnsName         |  ec2-54-93-244-69.eu-central-1.compute.amazonaws.com   |||
|||  PublicIpAddress       |  54.93.244.69                                          |||
|||  RootDeviceName        |  /dev/sda1                                             |||
|||  RootDeviceType        |  ebs                                                   |||
|||  SourceDestCheck       |  True                                                  |||
|||  StateTransitionReason |                                                        |||
|||  SubnetId              |  subnet-07a2d8e446b100c58                              |||
|||  VirtualizationType    |  hvm                                                   |||
|||  VpcId                 |  vpc-0b508a704edb473cb                                 |||
||+------------------------+--------------------------------------------------------+||
||||                              BlockDeviceMappings                              ||||
|||+----------------------------------------+--------------------------------------+|||
||||  DeviceName                            |  /dev/sda1                           ||||
|||+----------------------------------------+--------------------------------------+|||
|||||                                     Ebs                                     |||||
||||+----------------------------------+------------------------------------------+||||
|||||  AttachTime                      |  2020-04-26T14:25:06.000Z                |||||
|||||  DeleteOnTermination             |  True                                    |||||
|||||  Status                          |  attached                                |||||
|||||  VolumeId                        |  vol-0bd92088d60c8dceb                   |||||
||||+----------------------------------+------------------------------------------+||||
||||                                  Monitoring                                   ||||
|||+---------------------------------+---------------------------------------------+|||
||||  State                          |  disabled                                   ||||
|||+---------------------------------+---------------------------------------------+|||
||||                               NetworkInterfaces                               ||||
|||+-----------------------+-------------------------------------------------------+|||
||||  Description          |                                                       ||||
||||  MacAddress           |  02:cb:6d:43:8c:f0                                    ||||
||||  NetworkInterfaceId   |  eni-0b0c13a8df17bd2ad                                ||||
||||  OwnerId              |  143440624024                                         ||||
||||  PrivateDnsName       |  ip-10-42-255-153.eu-central-1.compute.internal       ||||
||||  PrivateIpAddress     |  10.42.255.153                                        ||||
||||  SourceDestCheck      |  True                                                 ||||
||||  Status               |  in-use                                               ||||
||||  SubnetId             |  subnet-07a2d8e446b100c58                             ||||
||||  VpcId                |  vpc-0b508a704edb473cb                                ||||
|||+-----------------------+-------------------------------------------------------+|||
|||||                                 Association                                 |||||
||||+-----------------+-----------------------------------------------------------+||||
|||||  IpOwnerId      |  amazon                                                   |||||
|||||  PublicDnsName  |  ec2-54-93-244-69.eu-central-1.compute.amazonaws.com      |||||
|||||  PublicIp       |  54.93.244.69                                             |||||
||||+-----------------+-----------------------------------------------------------+||||
|||||                                 Attachment                                  |||||
||||+-------------------------------+---------------------------------------------+||||
|||||  AttachTime                   |  2020-04-26T14:25:05.000Z                   |||||
|||||  AttachmentId                 |  eni-attach-0964ef9b0e7624e29               |||||
|||||  DeleteOnTermination          |  True                                       |||||
|||||  DeviceIndex                  |  0                                          |||||
|||||  Status                       |  attached                                   |||||
||||+-------------------------------+---------------------------------------------+||||
|||||                                   Groups                                    |||||
||||+--------------------------+--------------------------------------------------+||||
|||||  GroupId                 |  sg-084a86c98ad8c2128                            |||||
|||||  GroupName               |  default                                         |||||
||||+--------------------------+--------------------------------------------------+||||
|||||                             PrivateIpAddresses                              |||||
||||+---------------------+-------------------------------------------------------+||||
|||||  Primary            |  True                                                 |||||
|||||  PrivateDnsName     |  ip-10-42-255-153.eu-central-1.compute.internal       |||||
|||||  PrivateIpAddress   |  10.42.255.153                                        |||||
||||+---------------------+-------------------------------------------------------+||||
||||||                                Association                                ||||||
|||||+----------------+----------------------------------------------------------+|||||
||||||  IpOwnerId     |  amazon                                                  ||||||
||||||  PublicDnsName |  ec2-54-93-244-69.eu-central-1.compute.amazonaws.com     ||||||
||||||  PublicIp      |  54.93.244.69                                            ||||||
|||||+----------------+----------------------------------------------------------+|||||
||||                                   Placement                                   ||||
|||+------------------------------------------+------------------------------------+|||
||||  AvailabilityZone                        |  eu-central-1a                     ||||
||||  GroupName                               |                                    ||||
||||  Tenancy                                 |  default                           ||||
|||+------------------------------------------+------------------------------------+|||
||||                                SecurityGroups                                 ||||
|||+--------------------------+----------------------------------------------------+|||
||||  GroupId                 |  sg-084a86c98ad8c2128                              ||||
||||  GroupName               |  default                                           ||||
|||+--------------------------+----------------------------------------------------+|||
||||                                     State                                     ||||
|||+--------------------------------+----------------------------------------------+|||
||||  Code                          |  16                                          ||||
||||  Name                          |  running                                     ||||
|||+--------------------------------+----------------------------------------------+|||
||||                                     Tags                                      ||||
|||+-----------------------+-------------------------------------------------------+|||
||||  Key                  |  Name                                                 ||||
||||  Value                |  Ex. 4 web server                                     ||||
|||+-----------------------+-------------------------------------------------------+|||
||                                   Reservations                                    ||
|+----------------------------------+------------------------------------------------+|
||  OwnerId                         |  143440624024                                  ||
||  ReservationId                   |  r-03d4fbade42676184                           ||
|+----------------------------------+------------------------------------------------+|
|||                                    Instances                                    |||
||+--------------------------+------------------------------------------------------+||
|||  AmiLaunchIndex          |  0                                                   |||
|||  Architecture            |  x86_64                                              |||
|||  ClientToken             |                                                      |||
|||  EbsOptimized            |  False                                               |||
|||  EnaSupport              |  True                                                |||
|||  Hypervisor              |  xen                                                 |||
|||  ImageId                 |  ami-0e342d72b12109f91                               |||
|||  InstanceId              |  i-027f0cb1638fd711c                                 |||
|||  InstanceType            |  t2.micro                                            |||
|||  KeyName                 |  tf-pubcloud2020                                     |||
|||  LaunchTime              |  2020-04-26T14:25:04.000Z                            |||
|||  PrivateDnsName          |  ip-10-42-0-143.eu-central-1.compute.internal        |||
|||  PrivateIpAddress        |  10.42.0.143                                         |||
|||  PublicDnsName           |                                                      |||
|||  RootDeviceName          |  /dev/sda1                                           |||
|||  RootDeviceType          |  ebs                                                 |||
|||  SourceDestCheck         |  True                                                |||
|||  StateTransitionReason   |                                                      |||
|||  SubnetId                |  subnet-02521eb45700f5398                            |||
|||  VirtualizationType      |  hvm                                                 |||
|||  VpcId                   |  vpc-0b508a704edb473cb                               |||
||+--------------------------+------------------------------------------------------+||
||||                              BlockDeviceMappings                              ||||
|||+----------------------------------------+--------------------------------------+|||
||||  DeviceName                            |  /dev/sda1                           ||||
|||+----------------------------------------+--------------------------------------+|||
|||||                                     Ebs                                     |||||
||||+----------------------------------+------------------------------------------+||||
|||||  AttachTime                      |  2020-04-26T14:25:05.000Z                |||||
|||||  DeleteOnTermination             |  True                                    |||||
|||||  Status                          |  attached                                |||||
|||||  VolumeId                        |  vol-04c5697e3ac46667b                   |||||
||||+----------------------------------+------------------------------------------+||||
||||                                  Monitoring                                   ||||
|||+---------------------------------+---------------------------------------------+|||
||||  State                          |  disabled                                   ||||
|||+---------------------------------+---------------------------------------------+|||
||||                               NetworkInterfaces                               ||||
|||+-----------------------+-------------------------------------------------------+|||
||||  Description          |                                                       ||||
||||  MacAddress           |  0a:46:e4:e4:85:72                                    ||||
||||  NetworkInterfaceId   |  eni-005036578823f5482                                ||||
||||  OwnerId              |  143440624024                                         ||||
||||  PrivateDnsName       |  ip-10-42-0-143.eu-central-1.compute.internal         ||||
||||  PrivateIpAddress     |  10.42.0.143                                          ||||
||||  SourceDestCheck      |  True                                                 ||||
||||  Status               |  in-use                                               ||||
||||  SubnetId             |  subnet-02521eb45700f5398                             ||||
||||  VpcId                |  vpc-0b508a704edb473cb                                ||||
|||+-----------------------+-------------------------------------------------------+|||
|||||                                 Attachment                                  |||||
||||+-------------------------------+---------------------------------------------+||||
|||||  AttachTime                   |  2020-04-26T14:25:04.000Z                   |||||
|||||  AttachmentId                 |  eni-attach-004e24364fb807663               |||||
|||||  DeleteOnTermination          |  True                                       |||||
|||||  DeviceIndex                  |  0                                          |||||
|||||  Status                       |  attached                                   |||||
||||+-------------------------------+---------------------------------------------+||||
|||||                                   Groups                                    |||||
||||+--------------------------+--------------------------------------------------+||||
|||||  GroupId                 |  sg-084a86c98ad8c2128                            |||||
|||||  GroupName               |  default                                         |||||
||||+--------------------------+--------------------------------------------------+||||
|||||                             PrivateIpAddresses                              |||||
||||+---------------------+-------------------------------------------------------+||||
|||||  Primary            |  True                                                 |||||
|||||  PrivateDnsName     |  ip-10-42-0-143.eu-central-1.compute.internal         |||||
|||||  PrivateIpAddress   |  10.42.0.143                                          |||||
||||+---------------------+-------------------------------------------------------+||||
||||                                   Placement                                   ||||
|||+------------------------------------------+------------------------------------+|||
||||  AvailabilityZone                        |  eu-central-1c                     ||||
||||  GroupName                               |                                    ||||
||||  Tenancy                                 |  default                           ||||
|||+------------------------------------------+------------------------------------+|||
||||                                SecurityGroups                                 ||||
|||+--------------------------+----------------------------------------------------+|||
||||  GroupId                 |  sg-084a86c98ad8c2128                              ||||
||||  GroupName               |  default                                           ||||
|||+--------------------------+----------------------------------------------------+|||
||||                                     State                                     ||||
|||+--------------------------------+----------------------------------------------+|||
||||  Code                          |  16                                          ||||
||||  Name                          |  running                                     ||||
|||+--------------------------------+----------------------------------------------+|||
||||                                     Tags                                      ||||
|||+----------------------+--------------------------------------------------------+|||
||||  Key                 |  Name                                                  ||||
||||  Value               |  Ex. 4 private host                                    ||||
|||+----------------------+--------------------------------------------------------+|||
```

That is quite a lot of output. ;-)

Let's perform the connectivity tests asked for in the exercise description:

## (Manual) connectivity Tests

I have added the private SSH key to my SSH agent
in order to easily log into the EC2 instances.
The Terraform outputs should provide the necessary information
for the connection tests:

```
$ terraform show | sed -n '/Outputs:/,$p'
Outputs:

VPC_prefix = "10.42.0.0/16"
jump_host_ip = "18.185.67.143"
jump_host_name = "ec2-18-185-67-143.eu-central-1.compute.amazonaws.com"
private_host_ip = "10.42.255.147"
private_host_name = "ip-10-42-255-147.eu-central-1.compute.internal"
private_subnet_prefix = "10.42.0.0/24"
public_subnet_prefix = "10.42.255.0/24"
web_server_ip = "54.93.244.69"
web_server_name = "ec2-54-93-244-69.eu-central-1.compute.amazonaws.com"
```

### SSH Access to Web Server and Jump Host

I'll log into each of the two servers:

#### Web Server

```
$ ssh ubuntu@ec2-54-93-244-69.eu-central-1.compute.amazonaws.com
The authenticity of host 'ec2-54-93-244-69.eu-central-1.compute.amazonaws.com (54.93.244.69)' can't be established.
ECDSA key fingerprint is SHA256:gMj+Wlev2sujyOvk9Cwxg/J7fYtfil/CjRYXQl9A/JU.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'ec2-54-93-244-69.eu-central-1.compute.amazonaws.com,54.93.244.69' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-1065-aws x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sun Apr 26 14:44:53 UTC 2020

  System load:  0.08              Processes:           90
  Usage of /:   16.2% of 7.69GB   Users logged in:     0
  Memory usage: 17%               IP address for eth0: 10.42.255.153
  Swap usage:   0%

0 packages can be updated.
0 updates are security updates.



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@ip-10-42-255-153:~$ ls /var/www/html
index.html
ubuntu@ip-10-42-255-153:~$ logout
Connection to ec2-54-93-244-69.eu-central-1.compute.amazonaws.com closed.
```

#### Jump Host

```
$ ssh ubuntu@ec2-18-185-67-143.eu-central-1.compute.amazonaws.com
The authenticity of host 'ec2-18-185-67-143.eu-central-1.compute.amazonaws.com (18.185.67.143)' can't be established.
ECDSA key fingerprint is SHA256:Ewk1WUr4MJvrHJ/mfg0GMlbSvGcMNYXrTC3s1SRwF4g.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'ec2-18-185-67-143.eu-central-1.compute.amazonaws.com,18.185.67.143' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-1065-aws x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sun Apr 26 14:46:56 UTC 2020

  System load:  0.0               Processes:           86
  Usage of /:   16.0% of 7.69GB   Users logged in:     0
  Memory usage: 16%               IP address for eth0: 10.42.255.147
  Swap usage:   0%

0 packages can be updated.
0 updates are security updates.



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@ip-10-42-255-147:~$ ls /var/www/html
ls: cannot access '/var/www/html': No such file or directory
ubuntu@ip-10-42-255-147:~$ logout
Connection to ec2-18-185-67-143.eu-central-1.compute.amazonaws.com closed.
```

### Access the Web Server's Index Page

```
$ lynx -dump ec2-54-93-244-69.eu-central-1.compute.amazonaws.com
          PubCloud 2020 - Exercise 4 - Virtual Network Infrastructure

   This website is part of my solution to hands-on exercise 4 of the
   [1]Networking in Public Cloud Deployments course in the spring of 2020.

   This request was served from host ip-10-42-255-153 with local IP
   address 10.42.255.153 in availability zone eu-central-1a of region
   eu-central-1.

References

   1. https://www.ipspace.net/PubCloud/
```

### Access Private Subnet Instance via Jump Host

```
$ ssh ubuntu@10.42.255.147 -o ProxyJump=ubuntu@ec2-18-185-67-143.eu-central-1.compute.amazonaws.com
The authenticity of host '10.42.255.147 (<no hostip for proxy command>)' can't be established.
ECDSA key fingerprint is SHA256:Ewk1WUr4MJvrHJ/mfg0GMlbSvGcMNYXrTC3s1SRwF4g.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.42.255.147' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-1065-aws x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sun Apr 26 14:50:32 UTC 2020

  System load:  0.0               Processes:           89
  Usage of /:   16.0% of 7.69GB   Users logged in:     0
  Memory usage: 17%               IP address for eth0: 10.42.255.147
  Swap usage:   0%


0 packages can be updated.
0 updates are security updates.


Last login: Sun Apr 26 14:46:57 2020 from 46.114.1.35
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@ip-10-42-255-147:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 02:c8:4a:c6:fa:9c brd ff:ff:ff:ff:ff:ff
    inet 10.42.255.147/24 brd 10.42.255.255 scope global dynamic eth0
       valid_lft 2095sec preferred_lft 2095sec
    inet6 fe80::c8:4aff:fec6:fa9c/64 scope link
       valid_lft forever preferred_lft forever
ubuntu@ip-10-42-255-147:~$ ping -c2 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=49 time=1.22 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=49 time=1.13 ms

--- 8.8.8.8 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 1.134/1.180/1.227/0.057 ms
ubuntu@ip-10-42-255-147:~$ logout
Connection to 10.42.255.147 closed.
```

**That is wrong!**
The VM on the private subnet should have an IP address in the 10.42.0.0/24
network, not in 10.42.255.0/24.
It should not be able to access the Internet.
I'll have to look into this...

...well, I messed up the output definitions.
Thus the private IP given for the other VM
was actually the private IP address of the jump host.
I'll fix that and run `terraform apply` again:

```
$ terraform apply
aws_key_pair.course_ssh_key: Refreshing state... [id=tf-pubcloud2020]
data.aws_ami.gnu_linux_image: Refreshing state...
aws_vpc.ex4_vpc: Refreshing state... [id=vpc-0b508a704edb473cb]
aws_subnet.ex4_private: Refreshing state... [id=subnet-02521eb45700f5398]
aws_subnet.ex4_public: Refreshing state... [id=subnet-07a2d8e446b100c58]
aws_internet_gateway.ex4_igw: Refreshing state... [id=igw-0f441755d966d38af]
aws_default_security_group.def_sg: Refreshing state... [id=sg-084a86c98ad8c2128]
aws_instance.ex4_other: Refreshing state... [id=i-027f0cb1638fd711c]
aws_route_table.ex4_rt: Refreshing state... [id=rtb-0667e7f44e185c197]
aws_instance.ex4_jump: Refreshing state... [id=i-0e2bdac3c56bd21e5]
aws_instance.ex4_web: Refreshing state... [id=i-023b492515018c825]
aws_route_table_association.rt2public: Refreshing state... [id=rtbassoc-03399492da585a8f6]

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

VPC_prefix = 10.42.0.0/16
jump_host_ip = 18.185.67.143
jump_host_name = ec2-18-185-67-143.eu-central-1.compute.amazonaws.com
private_host_ip = 10.42.0.143
private_host_name = ip-10-42-0-143.eu-central-1.compute.internal
private_subnet_prefix = 10.42.0.0/24
public_subnet_prefix = 10.42.255.0/24
web_server_ip = 54.93.244.69
web_server_name = ec2-54-93-244-69.eu-central-1.compute.amazonaws.com
```

Now the other VM on the private subnet actually uses an IP address
from the private subnet.
Let's try the connecting via jump host again:

```
$ ssh -o ProxyJump=ubuntu@ec2-18-185-67-143.eu-central-1.compute.amazonaws.com ubuntu@10.42.0.143
The authenticity of host '10.42.0.143 (<no hostip for proxy command>)' can't be established.
ECDSA key fingerprint is SHA256:I+YKegzDgB9IEg3bpo825toaY7vfAgyWIONTPJ6A8PQ.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.42.0.143' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.4 LTS (GNU/Linux 4.15.0-1065-aws x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sun Apr 26 15:06:13 UTC 2020

  System load:  0.0               Processes:           86
  Usage of /:   13.7% of 7.69GB   Users logged in:     0
  Memory usage: 14%               IP address for eth0: 10.42.0.143
  Swap usage:   0%

0 packages can be updated.
0 updates are security updates.



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@ip-10-42-0-143:~$ ls /var/www/html
ls: cannot access '/var/www/html': No such file or directory
ubuntu@ip-10-42-0-143:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 0a:46:e4:e4:85:72 brd ff:ff:ff:ff:ff:ff
    inet 10.42.0.143/24 brd 10.42.0.255 scope global dynamic eth0
       valid_lft 2948sec preferred_lft 2948sec
    inet6 fe80::846:e4ff:fee4:8572/64 scope link
       valid_lft forever preferred_lft forever
ubuntu@ip-10-42-0-143:~$ ping -c2 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.

--- 8.8.8.8 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1024ms

ubuntu@ip-10-42-0-143:~$ ping -c2 10.42.255.153
PING 10.42.255.153 (10.42.255.153) 56(84) bytes of data.
64 bytes from 10.42.255.153: icmp_seq=1 ttl=64 time=0.944 ms
64 bytes from 10.42.255.153: icmp_seq=2 ttl=64 time=0.880 ms

--- 10.42.255.153 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.880/0.912/0.944/0.032 ms
ubuntu@ip-10-42-0-143:~$ ping -c2 10.42.255.147
PING 10.42.255.147 (10.42.255.147) 56(84) bytes of data.
64 bytes from 10.42.255.147: icmp_seq=1 ttl=64 time=0.896 ms
64 bytes from 10.42.255.147: icmp_seq=2 ttl=64 time=0.990 ms

--- 10.42.255.147 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1028ms
rtt min/avg/max/mdev = 0.896/0.943/0.990/0.047 ms
ubuntu@ip-10-42-0-143:~$ host www.ipspace.net
www.ipspace.net has address 104.26.2.69
www.ipspace.net has address 104.26.3.69
www.ipspace.net has IPv6 address 2606:4700:20::681a:345
www.ipspace.net has IPv6 address 2606:4700:20::681a:245
ubuntu@ip-10-42-0-143:~$ ping -c2 www.ipspace.net
PING www.ipspace.net (104.26.3.69) 56(84) bytes of data.

--- www.ipspace.net ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1023ms

ubuntu@ip-10-42-0-143:~$ logout
Connection to 10.42.0.143 closed.
```

That is better. :-)

### VM in Private Subnet Cannot Reach Internet

This was tested above.

## Where Are We Now?

So far I have created the mandatory pieces for this exercise.
Next on the agenda are *elastic IP address* and *elastic network interface*.
I will add them to the Terraform configuration and use `terraform apply`
to add them to the deployment.
But first I want to show the current state of the Terraform configuration:

```
$ cat vni.tf
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

# web server info
output "web_server_name" {
  value = aws_instance.ex4_web.public_dns
}
output "web_server_ip" {
  value = aws_instance.ex4_web.public_ip
}

# jump host info
output "jump_host_name" {
  value = aws_instance.ex4_jump.public_dns
}
output "jump_host_ip" {
  value = aws_instance.ex4_jump.public_ip
}

# private host info
output "private_host_name" {
  value = aws_instance.ex4_other.private_dns
}
output "private_host_ip" {
  value = aws_instance.ex4_other.private_ip
}
```

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
