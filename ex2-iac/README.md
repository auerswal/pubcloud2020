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
([Amazon Virtual Private Cloud](https://aws.amazon.com/vpc/)
(VPC) in the case of AWS).

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

In order to compare both tools I want to use similar inputs.

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

Reference documentation for AWS CLI usage is built into the program,
use `aws help` to access it.
If AWS CLI determines that output is sent to a terminal,
it automatically sends it through a pager.
The option `--no-paginate` does not work for help in my version of AWS CLI,
but piping the output through `cat` results in no pager being used:
`aws help | cat`.

The AWS CLI, written in Python, is slow.
On my system, `aws help` takes about one second to show any output,
whereas, e.g., `terraform -help` takes about one tenth of a second.

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

The template conforms to version *2010-09-09* of template specifications,
which is the only valid version at the time of writing.
While it is not necessary to explicitly specify the template version,
it might help in avoiding problems in the future.
If no template format version is given in a template,
AWS CloudFormation uses the most current (*latest*) available version.

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

Terraform uses the *HashiCorp Configuration Language* (HCL)
to describe infrastructure as code.
An infrastructure description using HCL is called a *configuration file*
or just a *configuration*.
Terraform configurations can be parameterized using *variables*.
Variables can be stored in files,
provided via environment variables,
or specified on the command line.
A configuration may comprise several files,
including variable definitions.

An HCL file can comprise more than one cloud provider,
therefore Terraform is called *platform agnostic*.
The platform-specific knowledge is contained in so called *providers*.
Terraform does not add an abstraction layer above different cloud platforms,
instead it allows combining different cloud platforms in one infrastructure
description.

While AWS CloudFormation optionally allows creating *change sets*,
Terraform always creates a *plan* of changes that need to be approved
prior to applying them.

Terraform can use the AWS CLI credentials file `~/.aws/credentials`
and will do so by default.
It will not use the AWS CLI configuration file `~/.aws/config`,
thus the AWS region to use needs to be specified as part of the
Terraform configuration.

#### Create a Single Public Cloud Resource

To create a VPC,
I write both a Terraform configuration file called
[vpc.tf](terraform/vpc.tf)
and a file with variable definitions called
[01-initial-parameters.tfvars](terraform/01-initial-parameters.tfvars).
While AWS CloudFormation does not prescribe file extensions,
Terraform requires `.tf` for configuration files
and recommends `.tfvars` for variable definition files.

    $ ls
    01-initial-parameters.tfvars  vpc.tf

I then use `terraform fmt` to format the configuration.
This commands prints the names of the files that have been changed
(similar to `go fmt` behavior):

    $ terraform fmt
    vpc.tf

The first step in deploying a Terraform configuration is to initialize
the Terraform working directory.
This step includes downloading the provider binaries for all providers
used in the configuration.
In my case the automatic download does not work,
because of my flakey network connection at home:

    $ terraform init
    
    Initializing the backend...
    
    Initializing provider plugins...
    - Checking for available provider plugins...
    - Downloading plugin for provider "aws" (hashicorp/aws) 2.52.0...
    
    Error installing provider "aws": stream error: stream ID 7; PROTOCOL_ERROR.
    
    Terraform analyses the configuration and state and automatically downloads
    plugins for the providers used. However, when attempting to download this
    plugin an unexpected error occurred.
    
    This may be caused if for some reason Terraform is unable to reach the
    plugin repository. The repository may be unreachable if access is blocked
    by a firewall.
    
    If automatic installation is not possible or desirable in your environment,
    you may alternatively manually install plugins by downloading a suitable
    distribution package and placing the plugin's executable file in the
    following directory:
        terraform.d/plugins/linux_amd64
    
    
    Error: stream error: stream ID 7; PROTOCOL_ERROR

Thus I manually download the provider binary
and install it in the subdirectory `terraform.d/plugins/linux_amd64`.
Afterwards `terraform init` succeeds:

    $ terraform init
    
    Initializing the backend...
    
    Initializing provider plugins...
    
    The following providers do not have any version constraints in configuration,
    so the latest version was installed.
    
    To prevent automatic upgrades to new major versions that may contain breaking
    changes, it is recommended to add version = "..." constraints to the
    corresponding provider blocks in configuration, with the constraint strings
    suggested below.
    
    * provider.aws: version = "~> 2.52"
    
    Terraform has been successfully initialized!
    
    You may now begin working with Terraform. Try running "terraform plan" to see
    any changes that are required for your infrastructure. All Terraform commands
    should now work.
    
    If you ever set or change modules or backend configuration for Terraform,
    rerun this command to reinitialize your working directory. If you forget, other
    commands will detect it and remind you to do so if necessary.

As recommended I fix the provider version number in the configuration file.
This may or may not result in less problems in the future
than always using the current provider version.
*YMMV* ;-)

The command `terraform init` has created a lock file in a hidden directory,
`.terraform/plugins/linux_amd64/lock.json`:

    $ find .
    .
    ./01-initial-parameters.tfvars
    ./vpc.tf
    ./.terraform
    ./.terraform/plugins
    ./.terraform/plugins/linux_amd64
    ./.terraform/plugins/linux_amd64/lock.json
    ./terraform.d
    ./terraform.d/plugins
    ./terraform.d/plugins/linux_amd64
    ./terraform.d/plugins/linux_amd64/terraform-provider-aws_v2.52.0_x4

I do not really like all that,
so I change the setup a bit.
Reading the terraform log file in the `/tmp` directory shows
that the provider binary is searched in the `$PATH` first.
Thus I move it next to the Terraform binary and remove the `terraform.d`
directory structure.
After removing the hidden `.terraform` directory structure, too,
I re-run `terraform init`.
It succeeds and creates the hidden directory structure and lock file.
I add `.terraform/` to my `.gitignore` file.
The Terraform setup should be good to go now.

The output of `terraform init` suggested running `terraform plan`
to see what needs to be done to
implement the configuration.
I rather validate the configuration first using `terraform validate`:

    $ terraform validate
    Success! The configuration is valid.

Now I want to see what Terraform plans to do:

    $ terraform plan
    Refreshing Terraform state in-memory prior to plan...
    The refreshed state will be used to calculate this plan, but will not be
    persisted to local or remote state storage.
    
    
    ------------------------------------------------------------------------
    
    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
      + create
    
    Terraform will perform the following actions:
    
      # aws_vpc.TheVPC will be created
      + resource "aws_vpc" "TheVPC" {
          + arn                              = (known after apply)
          + assign_generated_ipv6_cidr_block = false
          + cidr_block                       = "10.0.0.0/16"
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
              + "Name" = "unnamed"
            }
        }
    
    Plan: 1 to add, 0 to change, 0 to destroy.
    
    ------------------------------------------------------------------------
    
    Note: You didn't specify an "-out" parameter to save this plan, so Terraform
    can't guarantee that exactly these actions will be performed if
    "terraform apply" is subsequently run.

That is actually *not* what I wanted to do.
I forgot to specify the parameters for the VPC.
The command additionally tells me
that I need to *save* the plan
to guarantee that the shown plan will be used later
instead of coming up with a new plan then.
I will save the plans to a local subdirectory `plans`
and add the initial parameters:

    $ mkdir plans
    $ terraform plan --var-file 01-initial-parameters.tfvars -out plans/01-create-vpc.tfplan
    Refreshing Terraform state in-memory prior to plan...
    The refreshed state will be used to calculate this plan, but will not be
    persisted to local or remote state storage.
    
    
    ------------------------------------------------------------------------
    
    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
      + create
    
    Terraform will perform the following actions:
    
      # aws_vpc.TheVPC will be created
      + resource "aws_vpc" "TheVPC" {
          + arn                              = (known after apply)
          + assign_generated_ipv6_cidr_block = false
          + cidr_block                       = "10.47.0.0/16"
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
              + "Name" = "tf-vpc"
            }
        }
    
    Plan: 1 to add, 0 to change, 0 to destroy.
    
    ------------------------------------------------------------------------
    
    This plan was saved to: plans/01-create-vpc.tfplan
    
    To perform exactly these actions, run the following command to apply:
        terraform apply "plans/01-create-vpc.tfplan"

The Terraform plan is a ZIP archive:

    $ file plans/01-create-vpc.tfplan 
    plans/01-create-vpc.tfplan: Zip archive data, at least v2.0 to extract
    $ unzip -l plans/01-create-vpc.tfplan
    Archive:  plans/01-create-vpc.tfplan
      Length      Date    Time    Name
    ---------  ---------- -----   ----
          702  2020-03-08 17:59   tfplan
          121  2020-03-08 17:59   tfstate
         1396  2020-03-08 17:59   tfconfig/m-/vpc.tf
           41  2020-03-08 17:59   tfconfig/modules.json
    ---------                     -------
         2260                     4 files

The file `tfplan` is in a binary format and seems to be the actual plan.
The `tfstate` file is a JSON dictionary,
the `modules.json` file contains a JSON list of dictionaries,
and `vpc.tf` is a copy of the configuration file
without variable substitutions.
The `tfplan` file contains the values from the variable file.

I do not think this is interesting enough to keep in this repositary,
so I will delete the `plans/01-create-vpc.tfplan` file after use,
and just use `terraform apply -vars-file <file>`
for the remainder of this exercise.

But at first I will execute the generated plan to create a VPC:

    $ terraform apply plans/01-create-vpc.tfplan
    aws_vpc.TheVPC: Creating...
    aws_vpc.TheVPC: Creation complete after 7s [id=vpc-02179fb099bcecd94]
    
    Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
    
    The state of your infrastructure has been saved to the path
    below. This state is required to modify and destroy your
    infrastructure, so keep it safe. To inspect the complete state
    use the `terraform show` command.
    
    State path: terraform.tfstate
    
    Outputs:
    
    Prefix = 10.47.0.0/16
    VPC_ID = vpc-02179fb099bcecd94

This has (supposedly) created the VPC.
I check that via AWS CLI:

    $ aws ec2 describe-vpcs --filter Name=isDefault,Values=false
    -----------------------------------------------------------------------------------------------------------
    |                                              DescribeVpcs                                               |
    +---------------------------------------------------------------------------------------------------------+
    ||                                                 Vpcs                                                  ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    ||   CidrBlock  | DhcpOptionsId  | InstanceTenancy  | IsDefault  |    State    |          VpcId          ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    ||  10.47.0.0/16|  dopt-983cf3f2 |  default         |  False     |  available  |  vpc-02179fb099bcecd94  ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    |||                                       CidrBlockAssociationSet                                       |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    |||                            AssociationId                            |           CidrBlock           |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    |||  vpc-cidr-assoc-00e1cb09f0438ec4b                                   |  10.47.0.0/16                 |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    ||||                                          CidrBlockState                                           ||||
    |||+--------------------------------------+------------------------------------------------------------+|||
    ||||  State                               |  associated                                                ||||
    |||+--------------------------------------+------------------------------------------------------------+|||
    |||                                                Tags                                                 |||
    ||+--------------------------------------------+--------------------------------------------------------+||
    |||                     Key                    |                         Value                          |||
    ||+--------------------------------------------+--------------------------------------------------------+||
    |||  Name                                      |  tf-vpc                                                |||
    ||+--------------------------------------------+--------------------------------------------------------+||

Terraform reports to have written a *state file* called `terraform.tfstate`.
This is an ASCII file containing JSON data describing the created
infrastructure.
The command `terraform show` displays a subset of the state data in HCL format:

    $ terraform show 
    # aws_vpc.TheVPC:
    resource "aws_vpc" "TheVPC" {
        arn                              = "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-02179fb099bcecd94"
        assign_generated_ipv6_cidr_block = false
        cidr_block                       = "10.47.0.0/16"
        default_network_acl_id           = "acl-08a4cf78e1af64b01"
        default_route_table_id           = "rtb-0139d83b08199ff24"
        default_security_group_id        = "sg-022f78b57d2073a13"
        dhcp_options_id                  = "dopt-983cf3f2"
        enable_dns_hostnames             = true
        enable_dns_support               = true
        id                               = "vpc-02179fb099bcecd94"
        instance_tenancy                 = "default"
        main_route_table_id              = "rtb-0139d83b08199ff24"
        owner_id                         = "143440624024"
        tags                             = {
            "Name" = "tf-vpc"
        }
    }
    
    
    Outputs:
    
    Prefix = "10.47.0.0/16"
    VPC_ID = "vpc-02179fb099bcecd94"

While it may be interesting to see how the Terraform state changes over time,
I will omit the state files from version control
by adding `terraform.tfstate` to `.gitignore`.

#### Change the Created Resource

Next I will change the VPC parameters,
just as I did with AWS CloudFormation.
First I will change the name from `tf-vpc` to `Terraform-VPC`,
then I will change the CIDR prefix from `10.47.0.0/16` to `10.48.0.0/16`.
Again I expect the name (tag) change to keep the existing VPC,
but the prefix change requires removing and recreating the VPC.
Instead of using a plan file,
To do this I write two additional variable files:
[02-changed-name.tfvars](terraform/02-changed-name.tfvars)
and
[03-changed-prefix.tfvars](terraform/03-changed-prefix.tfvars).
I will just use `terraform apply` with the appropriate variable file:

    $ terraform apply -var-file 02-changed-name.tfvars 
    aws_vpc.TheVPC: Refreshing state... [id=vpc-02179fb099bcecd94]
    
    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
      ~ update in-place
    
    Terraform will perform the following actions:
    
      # aws_vpc.TheVPC will be updated in-place
      ~ resource "aws_vpc" "TheVPC" {
            arn                              = "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-02179fb099bcecd94"
            assign_generated_ipv6_cidr_block = false
            cidr_block                       = "10.47.0.0/16"
            default_network_acl_id           = "acl-08a4cf78e1af64b01"
            default_route_table_id           = "rtb-0139d83b08199ff24"
            default_security_group_id        = "sg-022f78b57d2073a13"
            dhcp_options_id                  = "dopt-983cf3f2"
            enable_dns_hostnames             = true
            enable_dns_support               = true
            id                               = "vpc-02179fb099bcecd94"
            instance_tenancy                 = "default"
            main_route_table_id              = "rtb-0139d83b08199ff24"
            owner_id                         = "143440624024"
          ~ tags                             = {
              ~ "Name" = "tf-vpc" -> "Terraform-VPC"
            }
        }
    
    Plan: 0 to add, 1 to change, 0 to destroy.
    
    Do you want to perform these actions?
      Terraform will perform the actions described above.
      Only 'yes' will be accepted to approve.
    
      Enter a value: yes
    
    aws_vpc.TheVPC: Modifying... [id=vpc-02179fb099bcecd94]
    aws_vpc.TheVPC: Modifications complete after 7s [id=vpc-02179fb099bcecd94]
    
    Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
    
    Outputs:
    
    Prefix = 10.47.0.0/16
    VPC_ID = vpc-02179fb099bcecd94

The `terraform show` command displays the changed state:

    $ terraform show
    # aws_vpc.TheVPC:
    resource "aws_vpc" "TheVPC" {
        arn                              = "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-02179fb099bcecd94"
        assign_generated_ipv6_cidr_block = false
        cidr_block                       = "10.47.0.0/16"
        default_network_acl_id           = "acl-08a4cf78e1af64b01"
        default_route_table_id           = "rtb-0139d83b08199ff24"
        default_security_group_id        = "sg-022f78b57d2073a13"
        dhcp_options_id                  = "dopt-983cf3f2"
        enable_dns_hostnames             = true
        enable_dns_support               = true
        id                               = "vpc-02179fb099bcecd94"
        instance_tenancy                 = "default"
        main_route_table_id              = "rtb-0139d83b08199ff24"
        owner_id                         = "143440624024"
        tags                             = {
            "Name" = "Terraform-VPC"
        }
    }
    
    
    Outputs:
    
    Prefix = "10.47.0.0/16"
    VPC_ID = "vpc-02179fb099bcecd94"

The VPC tag *Name* has changed,
but the VPC ID is still the same,
as can be verified using the AWS CLI:

    $ aws ec2 describe-vpcs --filter Name=isDefault,Values=false
    -----------------------------------------------------------------------------------------------------------
    |                                              DescribeVpcs                                               |
    +---------------------------------------------------------------------------------------------------------+
    ||                                                 Vpcs                                                  ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    ||   CidrBlock  | DhcpOptionsId  | InstanceTenancy  | IsDefault  |    State    |          VpcId          ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    ||  10.47.0.0/16|  dopt-983cf3f2 |  default         |  False     |  available  |  vpc-02179fb099bcecd94  ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    |||                                       CidrBlockAssociationSet                                       |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    |||                            AssociationId                            |           CidrBlock           |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    |||  vpc-cidr-assoc-00e1cb09f0438ec4b                                   |  10.47.0.0/16                 |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    ||||                                          CidrBlockState                                           ||||
    |||+--------------------------------------+------------------------------------------------------------+|||
    ||||  State                               |  associated                                                ||||
    |||+--------------------------------------+------------------------------------------------------------+|||
    |||                                                Tags                                                 |||
    ||+-------------------------------+---------------------------------------------------------------------+||
    |||              Key              |                                Value                                |||
    ||+-------------------------------+---------------------------------------------------------------------+||
    |||  Name                         |  Terraform-VPC                                                      |||
    ||+-------------------------------+---------------------------------------------------------------------+||

Now to the second part,
changing the CIDR block:

    $ terraform apply -var-file 03-changed-prefix.tfvars 
    aws_vpc.TheVPC: Refreshing state... [id=vpc-02179fb099bcecd94]
    
    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
    -/+ destroy and then create replacement
    
    Terraform will perform the following actions:
    
      # aws_vpc.TheVPC must be replaced
    -/+ resource "aws_vpc" "TheVPC" {
          ~ arn                              = "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-02179fb099bcecd94" -> (known after apply)
            assign_generated_ipv6_cidr_block = false
          ~ cidr_block                       = "10.47.0.0/16" -> "10.48.0.0/16" # forces replacement
          ~ default_network_acl_id           = "acl-08a4cf78e1af64b01" -> (known after apply)
          ~ default_route_table_id           = "rtb-0139d83b08199ff24" -> (known after apply)
          ~ default_security_group_id        = "sg-022f78b57d2073a13" -> (known after apply)
          ~ dhcp_options_id                  = "dopt-983cf3f2" -> (known after apply)
          + enable_classiclink               = (known after apply)
          + enable_classiclink_dns_support   = (known after apply)
            enable_dns_hostnames             = true
            enable_dns_support               = true
          ~ id                               = "vpc-02179fb099bcecd94" -> (known after apply)
            instance_tenancy                 = "default"
          + ipv6_association_id              = (known after apply)
          + ipv6_cidr_block                  = (known after apply)
          ~ main_route_table_id              = "rtb-0139d83b08199ff24" -> (known after apply)
          ~ owner_id                         = "143440624024" -> (known after apply)
            tags                             = {
                "Name" = "Terraform-VPC"
            }
        }
    
    Plan: 1 to add, 0 to change, 1 to destroy.
    
    Do you want to perform these actions?
      Terraform will perform the actions described above.
      Only 'yes' will be accepted to approve.
    
      Enter a value: yes
    
    aws_vpc.TheVPC: Destroying... [id=vpc-02179fb099bcecd94]
    aws_vpc.TheVPC: Destruction complete after 0s
    aws_vpc.TheVPC: Creating...
    aws_vpc.TheVPC: Creation complete after 7s [id=vpc-03f59f91f9c6797a5]
    
    Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
    
    Outputs:
    
    Prefix = 10.48.0.0/16
    VPC_ID = vpc-03f59f91f9c6797a5

Terraform prominently shows (in red color) that the VPC needs to be
destroyed and recreated.
Since Terraform requires confirmation for actually applying a plan,
unintended actions seem to be avoidable. ☺

The Terraform state has changed again:

    $ terraform show
    # aws_vpc.TheVPC:
    resource "aws_vpc" "TheVPC" {
        arn                              = "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-03f59f91f9c6797a5"
        assign_generated_ipv6_cidr_block = false
        cidr_block                       = "10.48.0.0/16"
        default_network_acl_id           = "acl-037fb2b755f0f4255"
        default_route_table_id           = "rtb-0927f8fb0ed8f2e52"
        default_security_group_id        = "sg-057a32cc9cbf579bf"
        dhcp_options_id                  = "dopt-983cf3f2"
        enable_dns_hostnames             = true
        enable_dns_support               = true
        id                               = "vpc-03f59f91f9c6797a5"
        instance_tenancy                 = "default"
        main_route_table_id              = "rtb-0927f8fb0ed8f2e52"
        owner_id                         = "143440624024"
        tags                             = {
            "Name" = "Terraform-VPC"
        }
    }
    
    
    Outputs:
    
    Prefix = "10.48.0.0/16"
    VPC_ID = "vpc-03f59f91f9c6797a5"

The AWS CLI confirms that the intended changes have been performed:

    $ aws ec2 describe-vpcs --filter Name=isDefault,Values=false
    -----------------------------------------------------------------------------------------------------------
    |                                              DescribeVpcs                                               |
    +---------------------------------------------------------------------------------------------------------+
    ||                                                 Vpcs                                                  ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    ||   CidrBlock  | DhcpOptionsId  | InstanceTenancy  | IsDefault  |    State    |          VpcId          ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    ||  10.48.0.0/16|  dopt-983cf3f2 |  default         |  False     |  available  |  vpc-03f59f91f9c6797a5  ||
    |+--------------+----------------+------------------+------------+-------------+-------------------------+|
    |||                                       CidrBlockAssociationSet                                       |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    |||                            AssociationId                            |           CidrBlock           |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    |||  vpc-cidr-assoc-0d3dec5113edf9c68                                   |  10.48.0.0/16                 |||
    ||+---------------------------------------------------------------------+-------------------------------+||
    ||||                                          CidrBlockState                                           ||||
    |||+--------------------------------------+------------------------------------------------------------+|||
    ||||  State                               |  associated                                                ||||
    |||+--------------------------------------+------------------------------------------------------------+|||
    |||                                                Tags                                                 |||
    ||+-------------------------------+---------------------------------------------------------------------+||
    |||              Key              |                                Value                                |||
    ||+-------------------------------+---------------------------------------------------------------------+||
    |||  Name                         |  Terraform-VPC                                                      |||
    ||+-------------------------------+---------------------------------------------------------------------+||

Terraform automatically creates a backup of the current state before
writing the new one,
and saves it in the file `terraform.tfstate.backup`.
This can be used to verify what changed during `terraform apply`:

    $ diff -U0 terraform.tfstate.backup terraform.tfstate
    --- terraform.tfstate.backup    2020-03-08 18:37:15.327684422 +0100
    +++ terraform.tfstate   2020-03-08 18:37:22.111875438 +0100
    @@ -4 +4 @@
    -  "serial": 4,
    +  "serial": 7,
    @@ -8 +8 @@
    -      "value": "10.47.0.0/16",
    +      "value": "10.48.0.0/16",
    @@ -12 +12 @@
    -      "value": "vpc-02179fb099bcecd94",
    +      "value": "vpc-03f59f91f9c6797a5",
    @@ -26 +26 @@
    -            "arn": "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-02179fb099bcecd94",
    +            "arn": "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-03f59f91f9c6797a5",
    @@ -28,4 +28,4 @@
    -            "cidr_block": "10.47.0.0/16",
    -            "default_network_acl_id": "acl-08a4cf78e1af64b01",
    -            "default_route_table_id": "rtb-0139d83b08199ff24",
    -            "default_security_group_id": "sg-022f78b57d2073a13",
    +            "cidr_block": "10.48.0.0/16",
    +            "default_network_acl_id": "acl-037fb2b755f0f4255",
    +            "default_route_table_id": "rtb-0927f8fb0ed8f2e52",
    +            "default_security_group_id": "sg-057a32cc9cbf579bf",
    @@ -37 +37 @@
    -            "id": "vpc-02179fb099bcecd94",
    +            "id": "vpc-03f59f91f9c6797a5",
    @@ -41 +41 @@
    -            "main_route_table_id": "rtb-0139d83b08199ff24",
    +            "main_route_table_id": "rtb-0927f8fb0ed8f2e52",

I add `terraform.tfstate.backup` to `.gitignore`, too.

#### Remove the Created Resource

To clean up
the infrastructure can be removed using `terraform destroy`.
The command again clearly shows what shall happen
and requires confirmation:

    $ terraform destroy 
    aws_vpc.TheVPC: Refreshing state... [id=vpc-03f59f91f9c6797a5]
    
    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
      - destroy
    
    Terraform will perform the following actions:
    
      # aws_vpc.TheVPC will be destroyed
      - resource "aws_vpc" "TheVPC" {
          - arn                              = "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-03f59f91f9c6797a5" -> null
          - assign_generated_ipv6_cidr_block = false -> null
          - cidr_block                       = "10.48.0.0/16" -> null
          - default_network_acl_id           = "acl-037fb2b755f0f4255" -> null
          - default_route_table_id           = "rtb-0927f8fb0ed8f2e52" -> null
          - default_security_group_id        = "sg-057a32cc9cbf579bf" -> null
          - dhcp_options_id                  = "dopt-983cf3f2" -> null
          - enable_dns_hostnames             = true -> null
          - enable_dns_support               = true -> null
          - id                               = "vpc-03f59f91f9c6797a5" -> null
          - instance_tenancy                 = "default" -> null
          - main_route_table_id              = "rtb-0927f8fb0ed8f2e52" -> null
          - owner_id                         = "143440624024" -> null
          - tags                             = {
              - "Name" = "Terraform-VPC"
            } -> null
        }
    
    Plan: 0 to add, 0 to change, 1 to destroy.
    
    Do you really want to destroy all resources?
      Terraform will destroy all your managed infrastructure, as shown above.
      There is no undo. Only 'yes' will be accepted to confirm.
    
      Enter a value: yes
    
    aws_vpc.TheVPC: Destroying... [id=vpc-03f59f91f9c6797a5]
    aws_vpc.TheVPC: Destruction complete after 1s
    
    Destroy complete! Resources: 1 destroyed.

The Terraform state is now practically empty:

    $ terraform show
    
    $ cat terraform.tfstate
    {
      "version": 4,
      "terraform_version": "0.12.23",
      "serial": 9,
      "lineage": "bd54365a-52fb-3335-659b-7b7eeb4729d8",
      "outputs": {},
      "resources": []
    }
    $ diff -U0 terraform.tfstate.backup terraform.tfstate
    --- terraform.tfstate.backup    2020-03-08 18:48:20.524418822 +0100
    +++ terraform.tfstate   2020-03-08 18:48:20.596341300 +0100
    @@ -4 +4 @@
    -  "serial": 7,
    +  "serial": 9,
    @@ -6,46 +6,2 @@
    -  "outputs": {
    -    "Prefix": {
    -      "value": "10.48.0.0/16",
    -      "type": "string"
    -    },
    -    "VPC_ID": {
    -      "value": "vpc-03f59f91f9c6797a5",
    -      "type": "string"
    -    }
    -  },
    -  "resources": [
    -    {
    -      "mode": "managed",
    -      "type": "aws_vpc",
    -      "name": "TheVPC",
    -      "provider": "provider.aws",
    -      "instances": [
    -        {
    -          "schema_version": 1,
    -          "attributes": {
    -            "arn": "arn:aws:ec2:eu-central-1:143440624024:vpc/vpc-03f59f91f9c6797a5",
    -            "assign_generated_ipv6_cidr_block": false,
    -            "cidr_block": "10.48.0.0/16",
    -            "default_network_acl_id": "acl-037fb2b755f0f4255",
    -            "default_route_table_id": "rtb-0927f8fb0ed8f2e52",
    -            "default_security_group_id": "sg-057a32cc9cbf579bf",
    -            "dhcp_options_id": "dopt-983cf3f2",
    -            "enable_classiclink": null,
    -            "enable_classiclink_dns_support": null,
    -            "enable_dns_hostnames": true,
    -            "enable_dns_support": true,
    -            "id": "vpc-03f59f91f9c6797a5",
    -            "instance_tenancy": "default",
    -            "ipv6_association_id": "",
    -            "ipv6_cidr_block": "",
    -            "main_route_table_id": "rtb-0927f8fb0ed8f2e52",
    -            "owner_id": "143440624024",
    -            "tags": {
    -              "Name": "Terraform-VPC"
    -            }
    -          },
    -          "private": "eyJzY2hlbWFfdmVyc2lvbiI6IjEifQ=="
    -        }
    -      ]
    -    }
    -  ]
    +  "outputs": {},
    +  "resources": []

The *private* instance data is Base64 encoded,
but not really interesting:

    $ echo eyJzY2hlbWFfdmVyc2lvbiI6IjEifQ== | base64 -d ; echo
    {"schema_version":"1"}

The AWS CLI confirms that the VPC has been removed
and only the default VPC remains:

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

I have to say that I liked using Terraform.
It feels more polished than using AWS CloudFormation via AWS CLI.
I think I may concentrate on Terraform for the following exercises,

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)

