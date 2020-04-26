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
3. Create a *route table* for the public subnet and add a default route
   pointing to the Internet Gateway.
4. Adjust the *default security group* to allow HTTP, HTTPS, and SSH
   to all virtual machines.  Use GUI if nexessary.
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
because *destroying* the Terraform would not have cleaned up
the changes to the default Security Group.

I have not yet created an
[elastic IP address](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
(EIP) nor an
[elastic network interface](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html)
(EMI).

In the [third exercise](../ex3-web/),
I have created a web server,
i.e., Apache running on Ubuntu,
provisioned with cloud-init.

Omitting the web server of the web server setup results in an SSH jump host,
or *another* VM instance.

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

Many route tables can be created and attached to different VPC objects,
thus allowing for some kind of *Policy Based Routing*.

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


---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
