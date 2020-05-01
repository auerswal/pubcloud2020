# Extra: Playing with Amazon Linux 2

I want to play a bit with
[Amazon Linux 2](https://aws.amazon.com/amazon-linux-2/)
instead of only using
[Ubuntu](https://ubuntu.com/).

I have used Ubuntu for both hands-on exercises
[three](../../ex3-web/)
and
[four](../../ex4-infra/).
While Ubuntu worked fine for running a web server in both exercises,
it did not nicely handle an additional *elastic network interface* (ENI).
I did find a workaround for the ENI problem,
but the AWS documentation claims
that Amazon Linux includes support for additional ENIs
via the package `ec2-net-utils`.
I expect this to just work,
possibly after add the `ec2-net-utils` package to cloud-config.

## Simple Web Server with Two Network Interfaces

I want to play both with using Amazon Linux 2 for a web server,
and adding an additional ENI.
Thus I create a
[Terraform configuration](amazon_linux_2.tf)
based on those from exercises three and four.

I want to find out two things:

1. Does the web server need explicit activation?
2. Does additional ENI support require explicit package installation?

Both above points are part of the
[cloud-config](web_server.cloud-config)
file.

### Initial Attempt

The initial file looks as follows:

```
#cloud-config
package_update: true
package_upgrade: true
packages:
  - apache2
write_files:
  - path: /var/www/html/index.html
    owner: 'root:root'
    permissions: '0644'
    content: |
      <html>
      <head>
       <title>PubCloud 2020 - Extra - Amazon Linux 2</title>
      </head>
      <body>
       <h1>PubCloud 2020 - Extra - Amazon Linux 2</h1>
       <p>Static web site running on Amazon Linux 2</p>
      </body>
      </html>
```

I use `terraform init` to initialize the Terraform workspace,
`terraform fmt` and then `terraform validate` to format and check the
configuration,
and then `terraform apply`:

```
$ terraform fmt
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

  # aws_instance.ec2_web will be created
  + resource "aws_instance" "ec2_web" {
      + ami                          = "ami-076431be05aaf8080"
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
          + "Name" = "Amazon Linux 2 Web Server EC2 Instance"
        }
      + tenancy                      = (known after apply)
      + user_data                    = "a89b15ed08b1001d85a70163a8d2b34df0cc4f79"
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

  # aws_internet_gateway.igw will be created
  + resource "aws_internet_gateway" "igw" {
      + id       = (known after apply)
      + owner_id = (known after apply)
      + tags     = {
          + "Name" = "Internet gateway"
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

  # aws_network_interface.eni will be created
  + resource "aws_network_interface" "eni" {
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

  # aws_route_table.rt will be created
  + resource "aws_route_table" "rt" {
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
          + "Name" = "route table for Internet access"
        }
      + vpc_id           = (known after apply)
    }

  # aws_route_table_association.rt2public will be created
  + resource "aws_route_table_association" "rt2public" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_subnet.private will be created
  + resource "aws_subnet" "private" {
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
          + "Name" = "private subnet"
        }
      + vpc_id                          = (known after apply)
    }

  # aws_subnet.public will be created
  + resource "aws_subnet" "public" {
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
          + "Name" = "public subnet"
        }
      + vpc_id                          = (known after apply)
    }

  # aws_vpc.vpc will be created
  + resource "aws_vpc" "vpc" {
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
          + "Name" = "VPC"
        }
    }

Plan: 10 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_key_pair.course_ssh_key: Creating...
aws_vpc.vpc: Creating...
aws_key_pair.course_ssh_key: Creation complete after 1s [id=tf-pubcloud2020]
aws_vpc.vpc: Creation complete after 7s [id=vpc-065e8836614487066]
aws_internet_gateway.igw: Creating...
aws_subnet.public: Creating...
aws_default_security_group.def_sg: Creating...
aws_subnet.public: Creation complete after 4s [id=subnet-0a7dff3ac1da7d2e3]
aws_subnet.private: Creating...
aws_internet_gateway.igw: Creation complete after 5s [id=igw-00fb41024a1ca3b6c]
aws_route_table.rt: Creating...
aws_instance.ec2_web: Creating...
aws_default_security_group.def_sg: Creation complete after 6s [id=sg-0b12e3bcfaf5acd53]
aws_subnet.private: Creation complete after 3s [id=subnet-08f464bc19986296e]
aws_route_table.rt: Creation complete after 3s [id=rtb-0cc9621d69dd8b0e1]
aws_route_table_association.rt2public: Creating...
aws_route_table_association.rt2public: Creation complete after 1s [id=rtbassoc-07d49b7d3af27399e]
aws_instance.ec2_web: Still creating... [10s elapsed]
aws_instance.ec2_web: Still creating... [20s elapsed]
aws_instance.ec2_web: Creation complete after 29s [id=i-00bd5764764ffe6b2]
aws_network_interface.eni: Creating...
aws_network_interface.eni: Creation complete after 3s [id=eni-0d1f6ced39e21fa8a]

Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

VPC_prefix = 10.42.0.0/16
eni_private_ip = 10.42.0.100
private_subnet_az = eu-central-1b
private_subnet_prefix = 10.42.0.0/24
public_subnet_az = eu-central-1b
public_subnet_prefix = 10.42.255.0/24
web_server_private_ip = 10.42.255.53
web_server_private_name = ip-10-42-255-53.eu-central-1.compute.internal
web_server_public_ip = 3.121.229.138
web_server_public_name = ec2-3-121-229-138.eu-central-1.compute.amazonaws.com
```

Well, the web server is not active:

```
$ lynx -dump ec2-3-121-229-138.eu-central-1.compute.amazonaws.com

Looking up ec2-3-121-229-138.eu-central-1.compute.amazonaws.com
Making HTTP connection to ec2-3-121-229-138.eu-central-1.compute.amazonaws.com
Alert!: Unable to connect to remote host.

lynx: Can't access startfile http://ec2-3-121-229-138.eu-central-1.compute.amazonaws.com/
```

Let's look at the ENI:

```
$ ssh ec2-user@ec2-3-121-229-138.eu-central-1.compute.amazonaws.com
Last login: Fri May  1 16:09:08 2020 from 46.114.4.172

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
No packages needed for security; 4 packages available
Run "sudo yum update" to apply all updates.
[ec2-user@ip-10-42-255-53 ~]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 06:e3:28:61:eb:5c brd ff:ff:ff:ff:ff:ff
    inet 10.42.255.53/24 brd 10.42.255.255 scope global dynamic eth0
       valid_lft 3179sec preferred_lft 3179sec
    inet6 fe80::4e3:28ff:fe61:eb5c/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 06:ab:00:fd:bb:76 brd ff:ff:ff:ff:ff:ff
    inet 10.42.0.100/24 brd 10.42.0.255 scope global dynamic eth1
       valid_lft 3192sec preferred_lft 3192sec
    inet6 fe80::4ab:ff:fefd:bb76/64 scope link
       valid_lft forever preferred_lft forever
```

So that worked.

Non-security updates were not installed,
although the cloud-config requested package updates.
That seems to require special treatment as well.

Amazon Linux 2 is a bit strange in that commands do not work via SSH:

```
$ ssh ec2-user@ec2-3-121-229-138.eu-central-1.compute.amazonaws.com ip address show
bash: ip: command not found
```

We have seen before that the iproute2 binary `ip` is available.
So all is not well with Amazon Linux 2 either.
It seems as if the `PATH` variable is set too late.
But SSH command mode does work,
as can be seen in the output from later attempts
(therefore we see different IP addresses and DNS names):

```
$ ssh ec2-user@ec2-3-121-87-192.eu-central-1.compute.amazonaws.com which ip
which: no ip in (/usr/local/bin:/usr/bin)
```
```
$ ssh ec2-user@ec2-3-121-87-192.eu-central-1.compute.amazonaws.com /sbin/ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 02:d2:58:01:cb:e2 brd ff:ff:ff:ff:ff:ff
    inet 10.42.255.72/24 brd 10.42.255.255 scope global dynamic eth0
       valid_lft 3523sec preferred_lft 3523sec
    inet6 fe80::d2:58ff:fe01:cbe2/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 02:51:2e:27:6b:22 brd ff:ff:ff:ff:ff:ff
    inet 10.42.0.180/24 brd 10.42.0.255 scope global dynamic eth1
       valid_lft 3545sec preferred_lft 3545sec
    inet6 fe80::51:2eff:fe27:6b22/64 scope link
       valid_lft forever preferred_lft forever
```

### Trying Again

Anyway, let's continue and activate the web server.
There are a couple of issues compared to Ubuntu:

1. The package is called `httpd`, not `apache2`.
2. The web server needs to be enabled explicitly.
3. Then the web server needs to be started manually.

So I'll destroy the deployment,
adjust the cloud-init configuration file,
and try again.

The cloud-config file now looks as follows:

```
#cloud-config
package_update: true
package_upgrade: true
packages:
  - httpd
write_files:
  - path: /var/www/html/index.html
    owner: 'root:root'
    permissions: '0644'
    content: |
      <html>
      <head>
       <title>PubCloud 2020 - Extra - Amazon Linux 2</title>
      </head>
      <body>
       <h1>PubCloud 2020 - Extra - Amazon Linux 2</h1>
       <p>Static web site running on Amazon Linux 2</p>
      </body>
      </html>
runcmd:
  - [ systemctl, enable, httpd ]
  - [ systemctl, start, httpd ]
```

The result of `terraform destroy` and `terraform apply`
is a running web server
with a functional ENI:

```
[...output omitted...]
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

VPC_prefix = 10.42.0.0/16
eni_private_ip = 10.42.0.115
private_subnet_az = eu-central-1b
private_subnet_prefix = 10.42.0.0/24
public_subnet_az = eu-central-1b
public_subnet_prefix = 10.42.255.0/24
web_server_private_ip = 10.42.255.9
web_server_private_name = ip-10-42-255-9.eu-central-1.compute.internal
web_server_public_ip = 3.122.230.250
web_server_public_name = ec2-3-122-230-250.eu-central-1.compute.amazonaws.com
```
```
$ lynx -dump ec2-3-122-230-250.eu-central-1.compute.amazonaws.com
                     PubCloud 2020 - Extra - Amazon Linux 2

   Static web site running on Amazon Linux 2
```
```
$ ssh ec2-user@ec2-3-122-230-250.eu-central-1.compute.amazonaws.com
The authenticity of host 'ec2-3-122-230-250.eu-central-1.compute.amazonaws.com (3.122.230.250)' can't be established.
ECDSA key fingerprint is SHA256:6ejDaKkiHueV2mBDz4JF2I1KEVMvfYibfw8zw8BPsyw.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'ec2-3-122-230-250.eu-central-1.compute.amazonaws.com,3.122.230.250' (ECDSA) to the list of known hosts.

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
No packages needed for security; 4 packages available
Run "sudo yum update" to apply all updates.
[ec2-user@ip-10-42-255-9 ~]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 06:9c:e8:a9:df:a0 brd ff:ff:ff:ff:ff:ff
    inet 10.42.255.9/24 brd 10.42.255.255 scope global dynamic eth0
       valid_lft 3407sec preferred_lft 3407sec
    inet6 fe80::49c:e8ff:fea9:dfa0/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 06:a7:3a:fb:2e:aa brd ff:ff:ff:ff:ff:ff
    inet 10.42.0.115/24 brd 10.42.0.255 scope global dynamic eth1
       valid_lft 3442sec preferred_lft 3442sec
    inet6 fe80::4a7:3aff:fefb:2eaa/64 scope link
       valid_lft forever preferred_lft forever
```

The cloud-init used by Amazon Linux 2 is documented to be modified,
without exhaustively describing the modifications.
That is OK,
but complete documentation would be better.
Anyway, package updates seem to require the following on Amazon Linux 2:

```
repo_update: true
repo_upgrade: all
```

### The Third Time is the Charm

So I modify the cloud-init configuration
[web\_server.cloud-config](web_server.cloud-config)
again:

```
#cloud-config
repo_update: true
repo_upgrade: all
packages:
  - httpd
write_files:
  - path: /var/www/html/index.html
    owner: 'root:root'
    permissions: '0644'
    content: |
      <html>
      <head>
       <title>PubCloud 2020 - Extra - Amazon Linux 2</title>
      </head>
      <body>
       <h1>PubCloud 2020 - Extra - Amazon Linux 2</h1>
       <p>Static web site running on Amazon Linux 2</p>
      </body>
      </html>
runcmd:
  - [ systemctl, enable, httpd ]
  - [ systemctl, start, httpd ]
```

This worked. :-)

```
[...output omitted...]
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

VPC_prefix = 10.42.0.0/16
eni_private_ip = 10.42.0.107
private_subnet_az = eu-central-1b
private_subnet_prefix = 10.42.0.0/24
public_subnet_az = eu-central-1b
public_subnet_prefix = 10.42.255.0/24
web_server_private_ip = 10.42.255.236
web_server_private_name = ip-10-42-255-236.eu-central-1.compute.internal
web_server_public_ip = 3.127.249.143
web_server_public_name = ec2-3-127-249-143.eu-central-1.compute.amazonaws.com
```
```
$ ssh ec2-user@ec2-3-127-249-143.eu-central-1.compute.amazonaws.com
The authenticity of host 'ec2-3-127-249-143.eu-central-1.compute.amazonaws.com (3.127.249.143)' can't be established.
ECDSA key fingerprint is SHA256:SnHJ1C1QSM8pfIpiTap+dAnAoCvwuLY47fUzgzfE1FM.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'ec2-3-127-249-143.eu-central-1.compute.amazonaws.com,3.127.249.143' (ECDSA) to the list of known hosts.

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
[ec2-user@ip-10-42-255-236 ~]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 06:b3:4a:71:e9:22 brd ff:ff:ff:ff:ff:ff
    inet 10.42.255.236/24 brd 10.42.255.255 scope global dynamic eth0
       valid_lft 3487sec preferred_lft 3487sec
    inet6 fe80::4b3:4aff:fe71:e922/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 06:f3:ba:84:c0:82 brd ff:ff:ff:ff:ff:ff
    inet 10.42.0.107/24 brd 10.42.0.255 scope global dynamic eth1
       valid_lft 3513sec preferred_lft 3513sec
    inet6 fe80::4f3:baff:fe84:c082/64 scope link
       valid_lft forever preferred_lft forever
[ec2-user@ip-10-42-255-236 ~]$ systemctl status httpd
● httpd.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd.service; enabled; vendor preset: disabled)
   Active: active (running) since Fr 2020-05-01 16:43:18 UTC; 1min 53s ago
     Docs: man:httpd.service(8)
 Main PID: 3491 (httpd)
   Status: "Total requests: 0; Idle/Busy workers 100/0;Requests/sec: 0; Bytes served/sec:   0 B/sec"
   CGroup: /system.slice/httpd.service
           ├─3491 /usr/sbin/httpd -DFOREGROUND
           ├─3492 /usr/sbin/httpd -DFOREGROUND
           ├─3493 /usr/sbin/httpd -DFOREGROUND
           ├─3494 /usr/sbin/httpd -DFOREGROUND
           ├─3495 /usr/sbin/httpd -DFOREGROUND
           └─3496 /usr/sbin/httpd -DFOREGROUND

Mai 01 16:43:18 ip-10-42-255-236.eu-central-1.compute.internal systemd[1]: St...
Mai 01 16:43:18 ip-10-42-255-236.eu-central-1.compute.internal systemd[1]: St...
Hint: Some lines were ellipsized, use -l to show in full.
[ec2-user@ip-10-42-255-236 ~]$ sudo yum update -y
Loaded plugins: extras_suggestions, langpacks, priorities, update-motd
No packages marked for update
[ec2-user@ip-10-42-255-236 ~]$ logout
Connection to ec2-3-127-249-143.eu-central-1.compute.amazonaws.com closed.
$ lynx -dump ec2-user@ec2-3-127-249-143.eu-central-1.compute.amazonaws.com
                     PubCloud 2020 - Extra - Amazon Linux 2

   Static web site running on Amazon Linux 2
```

Now all package updates have been applied,
Apache is installed, running, and serving the custom web page,
and the ENI is active without any additional action.

The need to explicitly enable and start the installed services
is a documented policy of Red Hat distributions and their
derivatives, including Amazon Linux 2.

## Cleaning Up

I clean up with `terraform destroy`, as always.

```
[...output omitted...]
Destroy complete! Resources: 10 destroyed.
```

## Conclusion

So the two questions have been answered:

1. Apache needs to be explicitly enabled and started on Amazon Linux 2.
2. A second *elastic network interface* (ENI) works out-of-the-box.

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
