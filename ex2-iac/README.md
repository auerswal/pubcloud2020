# Exercise 2: Simple Infrastructure-as-Code Setup

The second exercise concerns selecting a cloud provider,
selecting an infrastructure-as-code tool,
and using the selected tool for a first deployment of some infrastructure
at the selected cloud provider.

## Selecting the Public Cloud Provider

As hinted at in the
[exercise 1 solution](../ex1-reqs/)
I want to use
[Amazon Web Services](https://aws.amazon.com/)
(AWS) for the course exercises.

AWS supposedly fulfills all requirements of the exercises,
it is well known,
and seems to me to be a prototypical example of a public cloud.
The course material includes sections concerning AWS
(as well as sections about
[Microsoft Azure](https://azure.microsoft.com/)).

Since I do not have a good reason to use a different cloud offering,
I want to use one of those for which specific course material is available.
Both AWS and Azure provide some services for free for a limited time
and a limited amount of usage.
The free services of either should suffice for the course exercises.

I assume that I could use either of AWS and Azure for this course,
and arbitrarily decide on AWS.

## Selecting the Infrastructure-as-Code Tool

The course allows to use any *infrastructure-as-code* (IaC) tool,
including writing a custom solution,
as long as a few requirements are fulfilled.
The tool needs to support IaC concepts.
It needs to describe the infrastructure using some kind of code-like files that
can be tracked in a source code management (SCM) system.
The tool needs to support idempotent deployments.
The tool needs to support adds, removals, and changes.

A few examples for possible tools are given.
Both
[Ansible](https://www.ansible.com/)
and
[Terraform](https://www.terraform.io/)
supposedly meet all the requirements and can be used with different cloud
providers.
Some cloud providers offer specific IaC tools,
e.g.,
[AWS CloudFormation](https://aws.amazon.com/cloudformation/)
and
[Azure Resource Manager](https://azure.microsoft.com/en-us/features/resource-manager/).

I want to use a tool that is available as a package in
[Ubuntu](https://ubuntu.com/)
LTS, the GNU/Linux distribution I use.
This includes both Ansible (package `ansible`)
and AWS CloudFormation (as part of package `awscli`).
Terraform is available as a
[Snap](https://snapcraft.io/)
package,
but only in obsolete versions.
Terraform is distributed as a single binary
that does not need to be *installed*,
just copied to the system it shall be used on.
This binary then downloads additional binaries,
one per so called *provider*,
to a subdirectory of the current working directory.
Thus Terraform can easily be used (and disposed of) without need for
packaging.

I am using Ansible for network automation since a couple of years,
but I would rather take a look at something different.

Thus I will try out both Terraform and AWS CloudFormation for this exercise.
While AWS CloudFormation supports only AWS,
Terraform support several cloud offerings by using so called *providers*.
Terraform does not abstract the differences between cloud offerings,
but rather allows using different Terraform providers in a single
infrastructure description.
This seems to be similar to using different Ansible *modules* in a single
playbook.

## Your First Infrastructure-as-Code Deployment

This exercise requires creating a single public cloud resource,
e.g., one tenant network
(VPC in the case of AWS).

I am going to create two VPCs,
one using AWS CloudFormation,
the other using Terraform.
I do not want to try to use two different tools for controlling the *same*
cloud resource at this stage.
I need to learn the basic use of the tools first.

Thus I will use two VPCs for this exercise:

1. Use AWS CloudFormation to create a VPC with prefix `10.42.0.0/16`
   and name `cfn-vpc`.
2. Use Terraform to create a VPC with prefix `10.47.0.0/16`
   and name `tf-vpc`.

### Create a Single Public Cloud Resource

I want to create an
[Amazon Virtual Private Cloud](https://aws.amazon.com/vpc/)
(VPC).
Since I want to try out two different IaC tools,
I want to create two different VPCs.

#### Preliminaries

I have to create an account and set up programmatic access
before I can use an IaC tool with the selected public cloud.

##### Account Creation

At first I need to create an AWS account.
This is done by following the obvious link on the
[AWS](aws.amazon.com)
web site.
After filling in the requested data,
including credit card details and phone number,
and verification of both,
the account creation starts.
I receive an email after the account has been created.

##### API Access

API access keys need to be created in order to use the
[AWS CLI](https://aws.amazon.com/cli/).
The recommended way is to create a user,
during the user creation process it is recommended (required?) to create
a group as well.
The group is used to assign access rights to the user.
Access keys are generated for an API user
and can be downloaded in CSV format
or shown and copied from the web frontend.

The AWS CLI can be configured after obtaining API access keys:

    $ aws configure
    AWS Access Key ID [None]: <key id>
    AWS Secret Access Key [None]: <key>
    Default region name [None]: eu-central-1
    Default output format [None]: table

Sadly the AWS CLI version included in Ubuntu 18.04.4 LTS is too old to
support YAML as output format.

    $ aws --version
    aws-cli/1.14.44 Python/3.6.9 Linux/5.3.0-40-generic botocore/1.8.48

Primarily I want to read AWS CLI output
as opposed to using it as input for other AWS CLI commands,
thus I set the default to `table`.
I would have used `yaml` if supported,
because I find YAML easily readable, too.

Afterwards the AWS CLI is ready for use:

    $ aws ec2 describe-vpcs
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

#### AWS CloudFormation

#### Terraform

### Change the Created Resource

#### AWS CloudFormation

#### Terraform

### Remove the Created Resource

#### AWS CloudFormation

#### Terraform

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)

