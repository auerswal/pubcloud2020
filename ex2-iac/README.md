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

AWS CLI configuration is saved in the directory `~/.aws/`:

    $ ls ~/.aws
    config  credentials
    $ cat ~/.aws/config
    [default]
    region = eu-central-1
    output = table
    $ sed -E 's/^([^=]+= ?).*$/\1<redacted>/' ~/.aws/credentials
    [default]
    aws_access_key_id = <redacted>
    aws_secret_access_key = <redacted>

Using `aws configure` without options has created a configuration for
the `default` profile.

### AWS CloudFormation

First I will use AWS CloudFormation for this exercise.

AWS CloudFormation uses a model of *stacks*
that are deployed based on *templates*.
Templates can be parameterized.

While AWS CloudFormation can be used via web frontend,
I intend to use it via AWS CLI
using the command `cloudformation`
with its subcommands for individual actions.

I write a template named
[vpc-template.yaml](cloudformation/vpc-template.yaml)
that describes a single VPC
with one IPv4 prefix.
The template contains parameters for
the prefix and a name.
If no parameters are given
when using the template,
the default values specified in the template are used,
Other VPC properties are hard-coded in the template.

The template can be validated using `aws cloudformation validate-template`:

    $ aws cloudformation validate-template --template-body file://vpc-template.yaml
    --------------------------------------------------------------------------------
    |                               ValidateTemplate                               |
    +------------------+-----------------------------------------------------------+
    |  Description     |  Basic Virtual Private Cloud (VPC) template               |
    +------------------+-----------------------------------------------------------+
    ||                                 Parameters                                 ||
    |+--------------+----------------------------------+---------+----------------+|
    || DefaultValue |           Description            | NoEcho  | ParameterKey   ||
    |+--------------+----------------------------------+---------+----------------+|
    ||  10.0.0.0/16 |  IPv4 prefix (CIDR notation)     |  False  |  Ipv4Prefix    ||
    ||  unnamed     |  Name for this VPC (tag "name")  |  False  |  Name          ||
    |+--------------+----------------------------------+---------+----------------+|

Parameters can be given in *shorthand* or *JSON* syntax, but not *YAML* format
(at least for the AWS CLI version I have).
While shorthand syntax can only be provided as argument(s) to the
`--parameters` option,
JSON syntax can either be given as properly quoted argument to `--parameters`,
or read from file using `--parameters file://<path_to_file>`.

I have written two files to specify the initial parameters
to demonstrate the two different formats:

1. [01-initial-parameters](cloudformation/01-initial-parameters)
2. [01-initial-parameters.json](cloudformation/01-initial-parameters.json)

The option `--generate-cli-skeleton output` to the AWS CLI command
`aws cloudformation create-stack` can be used to validate
a template together with its parameters.

#### Create a Single Public Cloud Resource

In the beginning there are no stacks:

    $ aws cloudformation describe-stacks
    ----------------
    |DescribeStacks|
    +--------------+

There is a default VPC only:

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

First I validate the input parameters.
This only validates the basic syntax,
there can still be errors contained in the template or parameters,
e.g., an invalid parameter type.
Those kinds of errors can be seen by using the
`aws cloudformation describe-stacks` command
soon enough to still see the `ROLLBACK_IN_PROGRESS` status
with the associated `StackStatusReason`.

Every AWS CloudFormation stack needs a name;
I choose `ex2-cfn`.
I validate the stack creation command three times,
each using a different way to specify the template parameters:

    $ aws cloudformation create-stack --stack-name ex2-cfn --template-body file://vpc-template.yaml --parameters $(< 01-initial-parameters) --generate-cli-skeleton output
    ------------------------
    |      CreateStack     |
    +----------+-----------+
    |  StackId |  StackId  |
    +----------+-----------+
    $ aws cloudformation create-stack --stack-name ex2-cfn --template-body file://vpc-template.yaml --parameters "$(< 01-initial-parameters.json)" --generate-cli-skeleton output
    ------------------------
    |      CreateStack     |
    +----------+-----------+
    |  StackId |  StackId  |
    +----------+-----------+
    $ aws cloudformation create-stack --stack-name ex2-cfn --template-body file://vpc-template.yaml --parameters file://01-initial-parameters.json --generate-cli-skeleton output
    ------------------------
    |      CreateStack     |
    +----------+-----------+
    |  StackId |  StackId  |
    +----------+-----------+

From now on I will use the `--parameters file://<path_to_file>` variant.

The above commands have not yet created a CloudFormation stack,
they rather validated the input syntax
and generated sample output for the `create-stack` command.
The `create-stack` command prints the *stack ID* on success.

Now it is time to actually create the VPC:

    $ aws cloudformation create-stack --stack-name ex2-cfn --template-body file://vpc-template.yaml --parameters file://01-initial-parameters.json 
    --------------------------------------------------------------------------------------------------------------------
    |                                                    CreateStack                                                   |
    +---------+--------------------------------------------------------------------------------------------------------+
    |  StackId|  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   |
    +---------+--------------------------------------------------------------------------------------------------------+

The stack status can be checked using `aws cloudformation describe-stacks`:

    $ aws cloudformation describe-stacks
    ------------------------------------------------------------------------------------------------------------------------------
    |                                                       DescribeStacks                                                       |
    +----------------------------------------------------------------------------------------------------------------------------+
    ||                                                          Stacks                                                          ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    ||  CreationTime   |  2020-03-07T15:44:00.029Z                                                                              ||
    ||  Description    |  Basic Virtual Private Cloud (VPC) template                                                            ||
    ||  DisableRollback|  False                                                                                                 ||
    ||  StackId        |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   ||
    ||  StackName      |  ex2-cfn                                                                                               ||
    ||  StackStatus    |  CREATE_IN_PROGRESS                                                                                    ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    |||                                                       Parameters                                                       |||
    ||+-------------------------------------------------------+----------------------------------------------------------------+||
    |||                     ParameterKey                      |                        ParameterValue                          |||
    ||+-------------------------------------------------------+----------------------------------------------------------------+||
    |||  Ipv4Prefix                                           |  10.42.0.0/16                                                  |||
    |||  Name                                                 |  cfn-vpc                                                       |||
    ||+-------------------------------------------------------+----------------------------------------------------------------+||

After a while the stack is created:

    $ aws cloudformation describe-stacks
    ------------------------------------------------------------------------------------------------------------------------------
    |                                                       DescribeStacks                                                       |
    +----------------------------------------------------------------------------------------------------------------------------+
    ||                                                          Stacks                                                          ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    ||  CreationTime   |  2020-03-07T15:44:00.029Z                                                                              ||
    ||  Description    |  Basic Virtual Private Cloud (VPC) template                                                            ||
    ||  DisableRollback|  False                                                                                                 ||
    ||  StackId        |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   ||
    ||  StackName      |  ex2-cfn                                                                                               ||
    ||  StackStatus    |  CREATE_COMPLETE                                                                                       ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    |||                                                         Outputs                                                        |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||           Description          |          OutputKey          |                       OutputValue                       |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||  VPC ID                        |  VpcId                      |  vpc-08eabe5942dbb779e                                  |||
    |||  CIDR Prefix                   |  Prefix                     |  10.42.0.0/16                                           |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||                                                       Parameters                                                       |||
    ||+-------------------------------------------------------+----------------------------------------------------------------+||
    |||                     ParameterKey                      |                        ParameterValue                          |||
    ||+-------------------------------------------------------+----------------------------------------------------------------+||
    |||  Ipv4Prefix                                           |  10.42.0.0/16                                                  |||
    |||  Name                                                 |  cfn-vpc                                                       |||
    ||+-------------------------------------------------------+----------------------------------------------------------------+||

The resulting VPC can be seen with `aws ec2 describe-vpcs`.
There is the newly create VPC with name `cfn-vpc` and prefix `10.42.0.0/16`
as well as the default VPC seen before:

    $ aws ec2 describe-vpcs
    ----------------------------------------------------------------------------------------------------------------------------------------------
    |                                                                DescribeVpcs                                                                |
    +--------------------------------------------------------------------------------------------------------------------------------------------+
    ||                                                                   Vpcs                                                                   ||
    |+----------------------------------------------------------+-------------------------------------------------------------------------------+|
    ||  CidrBlock                                               |  10.42.0.0/16                                                                 ||
    ||  DhcpOptionsId                                           |  dopt-983cf3f2                                                                ||
    ||  InstanceTenancy                                         |  default                                                                      ||
    ||  IsDefault                                               |  False                                                                        ||
    ||  State                                                   |  available                                                                    ||
    ||  VpcId                                                   |  vpc-08eabe5942dbb779e                                                        ||
    |+----------------------------------------------------------+-------------------------------------------------------------------------------+|
    |||                                                         CidrBlockAssociationSet                                                        |||
    ||+------------------------------------------+---------------------------------------------------------------------------------------------+||
    |||  AssociationId                           |  vpc-cidr-assoc-002d982b07d1134ba                                                           |||
    |||  CidrBlock                               |  10.42.0.0/16                                                                               |||
    ||+------------------------------------------+---------------------------------------------------------------------------------------------+||
    ||||                                                            CidrBlockState                                                            ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    ||||  State                                            |  associated                                                                      ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    |||                                                                  Tags                                                                  |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    |||              Key              |                                                 Value                                                  |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    |||  name                         |  cfn-vpc                                                                                               |||
    |||  aws:cloudformation:stack-id  |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   |||
    |||  aws:cloudformation:logical-id|  TheVPC                                                                                                |||
    |||  aws:cloudformation:stack-name|  ex2-cfn                                                                                               |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    ||                                                                   Vpcs                                                                   ||
    |+------------------------------------------------------------------------+-----------------------------------------------------------------+|
    ||  CidrBlock                                                             |  172.31.0.0/16                                                  ||
    ||  DhcpOptionsId                                                         |  dopt-983cf3f2                                                  ||
    ||  InstanceTenancy                                                       |  default                                                        ||
    ||  IsDefault                                                             |  True                                                           ||
    ||  State                                                                 |  available                                                      ||
    ||  VpcId                                                                 |  vpc-7f13dc15                                                   ||
    |+------------------------------------------------------------------------+-----------------------------------------------------------------+|
    |||                                                         CidrBlockAssociationSet                                                        |||
    ||+---------------------------------------------------+------------------------------------------------------------------------------------+||
    |||  AssociationId                                    |  vpc-cidr-assoc-f576a99e                                                           |||
    |||  CidrBlock                                        |  172.31.0.0/16                                                                     |||
    ||+---------------------------------------------------+------------------------------------------------------------------------------------+||
    ||||                                                            CidrBlockState                                                            ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    ||||  State                                            |  associated                                                                      ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||

Listing of the *default* VPC can be omitted by using a filter:

    $ aws ec2 describe-vpcs --filter Name=isDefault,Values=false
    ----------------------------------------------------------------------------------------------------------------------------------------------
    |                                                                DescribeVpcs                                                                |
    +--------------------------------------------------------------------------------------------------------------------------------------------+
    ||                                                                   Vpcs                                                                   ||
    |+----------------------------------------------------------+-------------------------------------------------------------------------------+|
    ||  CidrBlock                                               |  10.42.0.0/16                                                                 ||
    ||  DhcpOptionsId                                           |  dopt-983cf3f2                                                                ||
    ||  InstanceTenancy                                         |  default                                                                      ||
    ||  IsDefault                                               |  False                                                                        ||
    ||  State                                                   |  available                                                                    ||
    ||  VpcId                                                   |  vpc-08eabe5942dbb779e                                                        ||
    |+----------------------------------------------------------+-------------------------------------------------------------------------------+|
    |||                                                         CidrBlockAssociationSet                                                        |||
    ||+------------------------------------------+---------------------------------------------------------------------------------------------+||
    |||  AssociationId                           |  vpc-cidr-assoc-002d982b07d1134ba                                                           |||
    |||  CidrBlock                               |  10.42.0.0/16                                                                               |||
    ||+------------------------------------------+---------------------------------------------------------------------------------------------+||
    ||||                                                            CidrBlockState                                                            ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    ||||  State                                            |  associated                                                                      ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    |||                                                                  Tags                                                                  |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    |||              Key              |                                                 Value                                                  |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    |||  name                         |  cfn-vpc                                                                                               |||
    |||  aws:cloudformation:stack-id  |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   |||
    |||  aws:cloudformation:logical-id|  TheVPC                                                                                                |||
    |||  aws:cloudformation:stack-name|  ex2-cfn                                                                                               |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||

#### Change the Created Resource

The first change I want to make is to change the name of the VPC
from `cfn-vpc` to `CloudFormation-VPC`.
This should modify the existing VPC,
because it just changes a *tag*.

I write a new parameters file
[02-changed-name.json](cloudformation/02-changed-name.json)
containing this change.
(For real usage I would check in an updated parameters file
instead of writing a new file.)
The same template can be used,
since the change pertains to the parameters only.

Changes to an AWS CloudFormation stack are applied with the
`aws cloudformation update-stack` command:

    $ aws cloudformation update-stack --stack-name ex2-cfn --use-previous-template --parameters file://02-changed-name.json
    --------------------------------------------------------------------------------------------------------------------
    |                                                    UpdateStack                                                   |
    +---------+--------------------------------------------------------------------------------------------------------+
    |  StackId|  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   |
    +---------+--------------------------------------------------------------------------------------------------------+

The name of the VPC was changed,
as can be seen both in the stack and VPC descriptions:

    $ aws cloudformation describe-stacks
    ------------------------------------------------------------------------------------------------------------------------------
    |                                                       DescribeStacks                                                       |
    +----------------------------------------------------------------------------------------------------------------------------+
    ||                                                          Stacks                                                          ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    ||  CreationTime   |  2020-03-07T15:44:00.029Z                                                                              ||
    ||  Description    |  Basic Virtual Private Cloud (VPC) template                                                            ||
    ||  DisableRollback|  False                                                                                                 ||
    ||  LastUpdatedTime|  2020-03-07T16:14:37.737Z                                                                              ||
    ||  StackId        |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   ||
    ||  StackName      |  ex2-cfn                                                                                               ||
    ||  StackStatus    |  UPDATE_COMPLETE                                                                                       ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    |||                                                         Outputs                                                        |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||           Description          |          OutputKey          |                       OutputValue                       |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||  VPC ID                        |  VpcId                      |  vpc-08eabe5942dbb779e                                  |||
    |||  CIDR Prefix                   |  Prefix                     |  10.42.0.0/16                                           |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||                                                       Parameters                                                       |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    |||                  ParameterKey                   |                           ParameterValue                             |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    |||  Ipv4Prefix                                     |  10.42.0.0/16                                                        |||
    |||  Name                                           |  CloudFormation-VPC                                                  |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    $ aws ec2 describe-vpcs --filter Name=isDefault,Values=false
    ----------------------------------------------------------------------------------------------------------------------------------------------
    |                                                                DescribeVpcs                                                                |
    +--------------------------------------------------------------------------------------------------------------------------------------------+
    ||                                                                   Vpcs                                                                   ||
    |+-------------------+----------------------+-------------------------+-----------------+-----------------+---------------------------------+|
    ||     CidrBlock     |    DhcpOptionsId     |     InstanceTenancy     |    IsDefault    |      State      |              VpcId              ||
    |+-------------------+----------------------+-------------------------+-----------------+-----------------+---------------------------------+|
    ||  10.42.0.0/16     |  dopt-983cf3f2       |  default                |  False          |  available      |  vpc-08eabe5942dbb779e          ||
    |+-------------------+----------------------+-------------------------+-----------------+-----------------+---------------------------------+|
    |||                                                         CidrBlockAssociationSet                                                        |||
    ||+----------------------------------------------------------------------------------------------+-----------------------------------------+||
    |||                                         AssociationId                                        |                CidrBlock                |||
    ||+----------------------------------------------------------------------------------------------+-----------------------------------------+||
    |||  vpc-cidr-assoc-002d982b07d1134ba                                                            |  10.42.0.0/16                           |||
    ||+----------------------------------------------------------------------------------------------+-----------------------------------------+||
    ||||                                                            CidrBlockState                                                            ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    ||||  State                                            |  associated                                                                      ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    |||                                                                  Tags                                                                  |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    |||              Key              |                                                 Value                                                  |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    |||  aws:cloudformation:stack-id  |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   |||
    |||  aws:cloudformation:logical-id|  TheVPC                                                                                                |||
    |||  aws:cloudformation:stack-name|  ex2-cfn                                                                                               |||
    |||  name                         |  CloudFormation-VPC                                                                                    |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||

Instead of directly updating the stack
I could have created a *change set*.
That would have allowed to review the changes before applying them.
I do not want to do this now.
Instead I will use the same procedure as before
to change the prefix from `10.42.0.0/16` to `10.43.0.0/16`.
I write a new parameter file
[03-changed-prefix.json](cloudformation/03-changed-prefix.json)
and use `aws cloudformation update-stack` again:

    $ aws cloudformation update-stack --stack-name ex2-cfn --use-previous-template --parameters file://03-changed-prefix.json
    --------------------------------------------------------------------------------------------------------------------
    |                                                    UpdateStack                                                   |
    +---------+--------------------------------------------------------------------------------------------------------+
    |  StackId|  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   |
    +---------+--------------------------------------------------------------------------------------------------------+

Now the VPC needs to be destroyed and recreated,
because the prefix is changed
(this is described in the documentation).
As a result a different VPC ID than before can be seen:

    $ aws cloudformation describe-stacks
    ------------------------------------------------------------------------------------------------------------------------------
    |                                                       DescribeStacks                                                       |
    +----------------------------------------------------------------------------------------------------------------------------+
    ||                                                          Stacks                                                          ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    ||  CreationTime   |  2020-03-07T15:44:00.029Z                                                                              ||
    ||  Description    |  Basic Virtual Private Cloud (VPC) template                                                            ||
    ||  DisableRollback|  False                                                                                                 ||
    ||  LastUpdatedTime|  2020-03-07T16:28:31.513Z                                                                              ||
    ||  StackId        |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   ||
    ||  StackName      |  ex2-cfn                                                                                               ||
    ||  StackStatus    |  UPDATE_COMPLETE                                                                                       ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    |||                                                         Outputs                                                        |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||           Description          |          OutputKey          |                       OutputValue                       |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||  VPC ID                        |  VpcId                      |  vpc-05741efb99d32e954                                  |||
    |||  CIDR Prefix                   |  Prefix                     |  10.43.0.0/16                                           |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||                                                       Parameters                                                       |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    |||                  ParameterKey                   |                           ParameterValue                             |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    |||  Ipv4Prefix                                     |  10.43.0.0/16                                                        |||
    |||  Name                                           |  CloudFormation-VPC                                                  |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    $ aws ec2 describe-vpcs --filter Name=isDefault,Values=false
    ----------------------------------------------------------------------------------------------------------------------------------------------
    |                                                                DescribeVpcs                                                                |
    +--------------------------------------------------------------------------------------------------------------------------------------------+
    ||                                                                   Vpcs                                                                   ||
    |+-------------------+----------------------+-------------------------+-----------------+-----------------+---------------------------------+|
    ||     CidrBlock     |    DhcpOptionsId     |     InstanceTenancy     |    IsDefault    |      State      |              VpcId              ||
    |+-------------------+----------------------+-------------------------+-----------------+-----------------+---------------------------------+|
    ||  10.43.0.0/16     |  dopt-983cf3f2       |  default                |  False          |  available      |  vpc-05741efb99d32e954          ||
    |+-------------------+----------------------+-------------------------+-----------------+-----------------+---------------------------------+|
    |||                                                         CidrBlockAssociationSet                                                        |||
    ||+----------------------------------------------------------------------------------------------+-----------------------------------------+||
    |||                                         AssociationId                                        |                CidrBlock                |||
    ||+----------------------------------------------------------------------------------------------+-----------------------------------------+||
    |||  vpc-cidr-assoc-037c8c2a044232183                                                            |  10.43.0.0/16                           |||
    ||+----------------------------------------------------------------------------------------------+-----------------------------------------+||
    ||||                                                            CidrBlockState                                                            ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    ||||  State                                            |  associated                                                                      ||||
    |||+---------------------------------------------------+----------------------------------------------------------------------------------+|||
    |||                                                                  Tags                                                                  |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    |||              Key              |                                                 Value                                                  |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||
    |||  aws:cloudformation:logical-id|  TheVPC                                                                                                |||
    |||  aws:cloudformation:stack-id  |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   |||
    |||  aws:cloudformation:stack-name|  ex2-cfn                                                                                               |||
    |||  name                         |  CloudFormation-VPC                                                                                    |||
    ||+-------------------------------+--------------------------------------------------------------------------------------------------------+||

#### Remove the Created Resource

As I understand it, a VPC does not incur extra costs,
but I want to remove it,
since I do not need it any more.
I use the `aws cloudformation delete-stack` command for this:

    $ aws cloudformation delete-stack --stack-name ex2-cfn
    $ aws cloudformation describe-stacks
    ------------------------------------------------------------------------------------------------------------------------------
    |                                                       DescribeStacks                                                       |
    +----------------------------------------------------------------------------------------------------------------------------+
    ||                                                          Stacks                                                          ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    ||  CreationTime   |  2020-03-07T15:44:00.029Z                                                                              ||
    ||  DeletionTime   |  2020-03-07T16:34:51.610Z                                                                              ||
    ||  Description    |  Basic Virtual Private Cloud (VPC) template                                                            ||
    ||  DisableRollback|  False                                                                                                 ||
    ||  LastUpdatedTime|  2020-03-07T16:28:31.513Z                                                                              ||
    ||  StackId        |  arn:aws:cloudformation:eu-central-1:143440624024:stack/ex2-cfn/57063780-608a-11ea-911a-029363dcbd8e   ||
    ||  StackName      |  ex2-cfn                                                                                               ||
    ||  StackStatus    |  DELETE_IN_PROGRESS                                                                                    ||
    |+-----------------+--------------------------------------------------------------------------------------------------------+|
    |||                                                         Outputs                                                        |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||           Description          |          OutputKey          |                       OutputValue                       |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||  VPC ID                        |  VpcId                      |  vpc-05741efb99d32e954                                  |||
    |||  CIDR Prefix                   |  Prefix                     |  10.43.0.0/16                                           |||
    ||+--------------------------------+-----------------------------+---------------------------------------------------------+||
    |||                                                       Parameters                                                       |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    |||                  ParameterKey                   |                           ParameterValue                             |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    |||  Ipv4Prefix                                     |  10.43.0.0/16                                                        |||
    |||  Name                                           |  CloudFormation-VPC                                                  |||
    ||+-------------------------------------------------+----------------------------------------------------------------------+||
    $ sleep 5m ; aws cloudformation describe-stacks
    ----------------
    |DescribeStacks|
    +--------------+

Now there are no more non-default VPCs:

    $ aws ec2 describe-vpcs --filter Name=isDefault,Values=false
    --------------
    |DescribeVpcs|
    +------------+
    $ aws ec2 describe-vpcs
    ---------------------------------------------------------------------------------------------------
    |                                          DescribeVpcs                                           |
    +-------------------------------------------------------------------------------------------------+
    ||                                             Vpcs                                              ||
    |+---------------+----------------+------------------+------------+-------------+----------------+|
    ||   CidrBlock   | DhcpOptionsId  | InstanceTenancy  | IsDefault  |    State    |     VpcId      ||
    |+---------------+----------------+------------------+------------+-------------+----------------+|
    ||  172.31.0.0/16|  dopt-983cf3f2 |  default         |  True      |  available  |  vpc-7f13dc15  ||
    |+---------------+----------------+------------------+------------+-------------+----------------+|
    |||                                   CidrBlockAssociationSet                                   |||
    ||+--------------------------------------------------------+------------------------------------+||
    |||                      AssociationId                     |             CidrBlock              |||
    ||+--------------------------------------------------------+------------------------------------+||
    |||  vpc-cidr-assoc-f576a99e                               |  172.31.0.0/16                     |||
    ||+--------------------------------------------------------+------------------------------------+||
    ||||                                      CidrBlockState                                       ||||
    |||+----------------------------------+--------------------------------------------------------+|||
    ||||  State                           |  associated                                            ||||
    |||+----------------------------------+--------------------------------------------------------+|||

This concludes the AWS CloudFormation part of the exercise.

### Terraform

I will repeat the exercise
(with different values than before)
using Terraform
to compare it with AWS CloudFormation.

#### Create a Single Public Cloud Resource

#### Change the Created Resource

#### Remove the Created Resource

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)

