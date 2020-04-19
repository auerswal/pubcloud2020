# Exercise 3: Deploy a Cloud-Based Web Server

The third exercise concerns deploying a single virtual machine running a
web server.
Choosing operating system and web server is left to the student,
with the caveat that help can only be provided for
[Ubuntu](https://ubuntu.com/)
with
[Apache](https://httpd.apache.org/) or
[nginx](https://nginx.org/).

This exercise is about creating a simple cloud solution comprising
a combination of compute and storage infrastructure.
Thus just creating an
[S3](https://aws.amazon.com/de/s3/)
bucket and enabling
[static website hosting](https://docs.aws.amazon.com/AmazonS3/latest/dev/HostingWebsiteOnS3Setup.html)
there misses the point.

## Overview

### Using Amazon Web Services

I will use
[Amazon Web Services](https://aws.amazon.com/)
(AWS) as with the previous exercises.
The exercise contains specific objectives for AWS:

1. Create an SSH key pair.
2. Deploy a virtual machine in the default VPC.
3. Create a public S3 bucket.
   Upload a picture (JPG or PNG file) of your choice into that bucket.
4. Turn the S3 bucket into a static web site.
5. Install and enable a web server
   (Apache or Nginx if you decided to use Linux)
   on your VM.
6. Add a static web page that references the picture in your cloud storage.
7. (Optional)
   Use server-side include to add `ifconfig` printout to the web page.
   You will need this (or similar) functionality when we'll deploy
   web servers in multiple availability zones.

Implementing just objectives 3 and 4 would result in a static web site,
but this would not help much in understanding how to combine
storage and compute in a cloud deployment.
Objective 7 seems to be intended to see which of the web servers has served
a request when accessing a web site via load balancer.

I intend to use
[GNU/Linux](https://www.gnu.org/gnu/linux-and-gnu.html),
either
[Amazon Linux 2](https://aws.amazon.com/amazon-linux-2/)
or
[Ubuntu](https://ubuntu.com/),
but have not yet decided on which of the two suggested web servers to use.
I have experience with
[Apache](https://httpd.apache.org/),
I have used
[lighttpd](https://www.lighttpd.net/)
in a project,
but have not yet done an
[nginx](https://nginx.org/)
installation.

For server provisioning I want to use
[cloud-init](https://cloud-init.io/).

I expect the solution to be one Terraform configuration.
I will try to build it step by step,
but do not yet know how each step will be documented.
I'll probably start with AWS CLI experiments.

## Exploring the Problem Space

I want to understand what lies beneath the simple cloud deployment.
Thus instead of grabbing example code from somewhere,
I want to look at all the different parts individually first.

### 1. Create an SSH Key Pair

An SSH key pair is used for (passwordless) command line access to a VM.
GNU/Linux systems use SSH for remote access from time immemorial,
and nowadays even
[Windows systems can provide SSH](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse)
access.

For AWS, an SSH key pair is an independent cloud resource.
An EC2 instance can use an SSH key pair.
Only *RSA* key pairs are supported according to AWS documentation.
SSH key pairs can be created by AWS,
or they can created outside of AWS and then imported.
If a key pair is created outside of AWS
and only the public half is uploaded,
AWS cannot know the private half of it.
Instead of using one of my existing SSH key pairs,
I create a new one just for this course using `ssh-keygen` from
[OpenSSH](https://www.openssh.com/):

    $ ssh-keygen -b 4096 -t rsa -f pubcloud2020_rsa_id
    Generating public/private rsa key pair.
    Enter passphrase (empty for no passphrase):
    Enter same passphrase again:
    Your identification has been saved in pubcloud2020_rsa_id.
    Your public key has been saved in pubcloud2020_rsa_id.pub.
    The key fingerprint is:
    SHA256:xD4sPny4tuxUGnFx39LLcob8s0eNPDETEFCtaLkWP0w auerswald@<redacted>
    The key's randomart image is:
    +---[RSA 4096]----+
    |        . oo++   |
    |       . o . oo  |
    |      . +  oo.o. |
    |       *  =.E++. |
    |      o S. *+.==.|
    |     o * .o +=+ o|
    |      B ..   .oo |
    |     o.+       o.|
    |     o=.      .. |
    +----[SHA256]-----+

This "key pair" can then be imported using the AWS CLI command
`aws ec2 import-key-pair`.
This imports only the public key, i.e., half the key pair.
At first, there are no key pairs:

    $ aws ec2 describe-key-pairs
    ------------------
    |DescribeKeyPairs|
    +----------------+
    $ aws ec2 describe-key-pairs --output json
    {
          "KeyPairs": []
    }

Then I upload the public key I want to use:

    $ aws ec2 import-key-pair --key-name 'PubCloud2020' --public-key-material file://pubcloud2020_rsa_id.pub
    ---------------------------------------------------------------------
    |                           ImportKeyPair                           |
    +---------------------------------------------------+---------------+
    |                  KeyFingerprint                   |    KeyName    |
    +---------------------------------------------------+---------------+
    |  bc:c0:ba:de:c1:2d:a8:38:5d:08:33:ba:dd:18:db:c4  |  PubCloud2020 |
    +---------------------------------------------------+---------------+

Now there is an SSH key pair available for use with EC2 instances:

    $ aws ec2 describe-key-pairs
    -----------------------------------------------------------------------
    |                          DescribeKeyPairs                           |
    +---------------------------------------------------------------------+
    ||                             KeyPairs                              ||
    |+---------------------------------------------------+---------------+|
    ||                  KeyFingerprint                   |    KeyName    ||
    |+---------------------------------------------------+---------------+|
    ||  bc:c0:ba:de:c1:2d:a8:38:5d:08:33:ba:dd:18:db:c4  |  PubCloud2020 ||
    |+---------------------------------------------------+---------------+|

I am not sure if this has worked correctly,
because the key fingerprint shown in the AWS CLI output
does *not* match the fingerprint shown by OpenSSH:

    $ ssh-keygen -l -E md5 -f pubcloud2020_rsa_id.pub
    4096 MD5:a6:a4:be:a2:7a:b5:bd:74:f6:75:7e:66:22:ad:22:ac auerswald@<redacted> (RSA)
    $ awk '{print $2}' pubcloud2020_rsa_id.pub | base64 -d | md5sum
    a6a4bea27ab5bd74f6757e6622ad22ac  -

A quick web search turns up the answer that AWS uses a different key format
than OpenSSH when calculating the key fingerprint.
To calculate the AWS fingerprint,
the key has to converted to the matching format first, i.e.,
to a DER encoding:

    $ ssh-keygen -e -m PKCS8 -f pubcloud2020_rsa_id.pub | openssl pkey -pubin -pubout -outform DER | md5sum
    bcc0badec12da8385d0833badd18dbc4  -
    $ aws ec2 describe-key-pairs --output text | fgrep PubCloud2020 | cut -f2 | tr -d :
    bcc0badec12da8385d0833badd18dbc4

So in the end uploading (*importing*) the existing OpenSSH key did work
correctly.

If you let AWS create a key pair for you,
all you get is the private key
and a fingerprint of the public key.

I want to use a Terraform configuration for this deployment,
and it seems as if Terraform does support uploading of public SSH keys
via the
[aws\_key\_pair](https://www.terraform.io/docs/providers/aws/r/key_pair.html)
resource and / or the `terraform import` command.
(At first glance `terraform import` seems to be an alternative to
manually creating the resource.)
Thus I will delete the manually uploaded public SSH key from AWS
before continuing:

    $ aws ec2 delete-key-pair --key-name PubCloud2020
    $ aws ec2 describe-key-pairs
    ------------------
    |DescribeKeyPairs|
    +----------------+
    $ aws ec2 describe-key-pairs --output json
    {
          "KeyPairs": []
    }

As far as I understand it the default security group used for the default VPC
does not allow SSH access.
Thus I expect to need to either update the default security group,
or create a suitable security group as well.

### 2. Deploy a VM in the default VPC

Deploying a virtual machine (VM) respectively EC2 instance is a preparatory
step if the intent is to later configure it,
either manually,
or using a configuration management system.
Since I want to use *cloud-init* to combine deployment and provisioning,
I will not yet start an EC2 instance in this step.

#### Determining the AMI ID

Starting a virtual machine on
[AWS EC2](https://aws.amazon.com/ec2/)
requires a so called
[Amazon Machine Image](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
(AMI).
The AMI to use is specified using a so called
[AMI ID](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html).

I intend to use
[Terraform](https://www.terraform.io/)
to determine the AMI ID to use based on a set of contraints,
but first I want to take a look at the problem space using the
[AWS CLI](https://aws.amazon.com/cli/).

I want to use either
[Amazon Linux 2](https://aws.amazon.com/amazon-linux-2/)
or
[Ubuntu](https://ubuntu.com/)
for this exercise.
Both supposedly support
[cloud-init](https://cloud-init.io/).
I want to use cloud-init to provision the web server.
Recent cloud-init versions supposedly support
[Jinja2](http://jinja.pocoo.org/)
templating.
I plan on using templating together with
[AWS instance metadata](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)
to render the instance specific HTML page
for the optional part 7 of the exercise.
Since I have not yet used cloud-init
and do not know which version is included in Amazon Linux 2,
I plan on keeping Ubuntu as a fallback.

The comprehensive
[AWS documentation](https://docs.aws.amazon.com/)
provides
[examples](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html#finding-an-ami-aws-cli)
for finding AMI IDs for, e.g., the latest Amazon Linux 2 or Ubuntu AMIs.
Currently (2020-04-12) this gives the following result for the `eu-central-1`
region:

    $ { aws ec2 describe-images --owners amazon \
    > --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2' \
    >           'Name=state,Values=available' \
    > --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' \
    > --output text; \
    > aws ec2 describe-images --owners 099720109477 --filters \
    > 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-server-????????' \
    > 'Name=state,Values=available' \
    > --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' \
    > --output text; } \
    > | while read -r AMI; \
    >   do aws ec2 describe-images --image-ids "$AMI" --output text | head -n1; \
    >   done | cut -f4,7 | tcat -F '\t' -vOFS=': '
    Amazon Linux 2 AMI 2.0.20200406.0 x86_64 HVM gp2                    : ami-076431be05aaf8080
    Canonical, Ubuntu, 18.04 LTS, amd64 bionic image build on 2020-04-08: ami-0e342d72b12109f91

(The
[`tcat`](https://github.com/auerswal/junkcode/blob/master/tcat)
above is a small Awk script written by me and available on GitHub.
It is inspired by Russ Cox's
[`tcat`](https://rsc.io/tcat)
implementation in Go.)

The filter values may come in handy when trying to use Terraform's
[AMI Data Source](https://www.terraform.io/docs/providers/aws/d/ami.html).

#### Security Group

The default security group of the default VPC does not allow any access
from the Internet.
We need both SSH and web access for this exercise.
SSH is needed for troubleshooting
and possibly provisioning of the web server.
Web access is needed for the service to be useful.
I do not intend to set up TLS certificates,
but web server packages often include self-signed certificates
and default TLS access,
so I will allow both insecure and secure web access.

For reference I will update the default security group to allow access,
and then remove that again,
since I want to have the security group settings as part of the Terraform
configuration.

    $ aws ec2 describe-security-groups --output json
    {
        "SecurityGroups": [
            {
                "Description": "default VPC security group",
                "GroupName": "default",
                "IpPermissions": [
                    {
                        "IpProtocol": "-1",
                        "IpRanges": [],
                        "Ipv6Ranges": [],
                        "PrefixListIds": [],
                        "UserIdGroupPairs": [
                            {
                                "GroupId": "sg-805b23e7",
                                "UserId": "143440624024"
                            }
                        ]
                    }
                ],
                "OwnerId": "143440624024",
                "GroupId": "sg-805b23e7",
                "IpPermissionsEgress": [
                    {
                        "IpProtocol": "-1",
                        "IpRanges": [
                            {
                                "CidrIp": "0.0.0.0/0"
                            }
                        ],
                        "Ipv6Ranges": [],
                        "PrefixListIds": [],
                        "UserIdGroupPairs": []
                    }
                ],
                "VpcId": "vpc-7f13dc15"
            }
        ]
    }
    $ aws ec2 authorize-security-group-ingress --group-name default --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "SSH access from the Internet"}]}, {"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "HTTP access from the Internet"}]}, {"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "HTTPS access from the Internet"}]}]'
    $ aws ec2 describe-security-groups --output json
    {
        "SecurityGroups": [
            {
                "Description": "default VPC security group",
                "GroupName": "default",
                "IpPermissions": [
                    {
                        "FromPort": 80,
                        "IpProtocol": "tcp",
                        "IpRanges": [
                            {
                                "CidrIp": "0.0.0.0/0",
                                "Description": "HTTP access from the Internet"
                            }
                        ],
                        "Ipv6Ranges": [],
                        "PrefixListIds": [],
                        "ToPort": 80,
                        "UserIdGroupPairs": []
                    },
                    {
                        "IpProtocol": "-1",
                        "IpRanges": [],
                        "Ipv6Ranges": [],
                        "PrefixListIds": [],
                        "UserIdGroupPairs": [
                            {
                                "GroupId": "sg-805b23e7",
                                "UserId": "143440624024"
                            }
                        ]
                    },
                    {
                        "FromPort": 22,
                        "IpProtocol": "tcp",
                        "IpRanges": [
                            {
                                "CidrIp": "0.0.0.0/0",
                                "Description": "SSH access from the Internet"
                            }
                        ],
                        "Ipv6Ranges": [],
                        "PrefixListIds": [],
                        "ToPort": 22,
                        "UserIdGroupPairs": []
                    },
                    {
                        "FromPort": 443,
                        "IpProtocol": "tcp",
                        "IpRanges": [
                            {
                                "CidrIp": "0.0.0.0/0",
                                "Description": "HTTPS access from the Internet"
                            }
                        ],
                        "Ipv6Ranges": [],
                        "PrefixListIds": [],
                        "ToPort": 443,
                        "UserIdGroupPairs": []
                    }
                ],
                "OwnerId": "143440624024",
                "GroupId": "sg-805b23e7",
                "IpPermissionsEgress": [
                    {
                        "IpProtocol": "-1",
                        "IpRanges": [
                            {
                                "CidrIp": "0.0.0.0/0"
                            }
                        ],
                        "Ipv6Ranges": [],
                        "PrefixListIds": [],
                        "UserIdGroupPairs": []
                    }
                ],
                "VpcId": "vpc-7f13dc15"
            }
        ]
    }
    $ aws ec2 describe-security-groups --output text
    SECURITYGROUPS  default VPC security group      sg-805b23e7     default 143440624024    vpc-7f13dc15
    IPPERMISSIONS   80      tcp     80
    IPRANGES        0.0.0.0/0       HTTP access from the Internet
    IPPERMISSIONS           -1
    USERIDGROUPPAIRS        sg-805b23e7     143440624024
    IPPERMISSIONS   22      tcp     22
    IPRANGES        0.0.0.0/0       SSH access from the Internet
    IPPERMISSIONS   443     tcp     443
    IPRANGES        0.0.0.0/0       HTTPS access from the Internet
    IPPERMISSIONSEGRESS     -1
    IPRANGES        0.0.0.0/0
    $ aws ec2 revoke-security-group-ingress --group-name default --protocol tcp --port 22 --cidr 0.0.0.0/0
    $ aws ec2 describe-security-groups --output text
    SECURITYGROUPS  default VPC security group      sg-805b23e7     default 143440624024    vpc-7f13dc15
    IPPERMISSIONS   80      tcp     80
    IPRANGES        0.0.0.0/0       HTTP access from the Internet
    IPPERMISSIONS           -1
    USERIDGROUPPAIRS        sg-805b23e7     143440624024
    IPPERMISSIONS   443     tcp     443
    IPRANGES        0.0.0.0/0       HTTPS access from the Internet
    IPPERMISSIONSEGRESS     -1
    IPRANGES        0.0.0.0/0
    $ aws ec2 revoke-security-group-ingress --group-name default --protocol tcp --port 80 --cidr 0.0.0.0/0
    $ aws ec2 revoke-security-group-ingress --group-name default --protocol tcp --port 443 --cidr 0.0.0.0/0
    $ aws ec2 describe-security-groups --output text
    SECURITYGROUPS  default VPC security group      sg-805b23e7     default 143440624024    vpc-7f13dc15
    IPPERMISSIONS   -1
    USERIDGROUPPAIRS        sg-805b23e7     143440624024
    IPPERMISSIONSEGRESS     -1
    IPRANGES        0.0.0.0/0

#### Start an EC2 Instance

Instead of starting an EC2 instance now,
I will just check that I have all prerequisites ready.
According to the
[documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-services-ec2-instances.html),
starting (*launching*) an EC2 instance requires:
* a key pair,
* a security group.

Both have been created respectively updated before.

I no availablity zone is specified,
AWS chooses one.
The VPC to use is specified via the subnet to use.
If no subnet is specified,
one of the default subnets is chosen by AWS.
If no security group is specified,
the default security group is used.

Another important thing is to specify the correct *instance type*.
This is especially important if you want to use the *free tier*,
since only specific instance types are *free tier eligible*.
This
[currently](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-limits.html)
includes the
*t1.micro*, *t2.micro*, and *t3.micro*
instance types.

Each start of an instance consumes 1h of budget,
thus it may not be advisable to start lots of instances for testing purposes.

### 3. Create a Public S3 Bucket

Amazon S3 is included in the free tier with limits
that should suffice for the course.
Using a little bit of storage and accessing it
should not cost much, if anything,
so I will set up the S3 hosted static website manually before using Terraform.

[Amazon Simple Storage Service](https://aws.amazon.com/s3/)
(S3)
is organized with so called *buckets*.
Buckets store individual files.
To store an image in S3,
first there needs to be a bucket.
Then the data can be copied to the bucket.
File permissions can be set when copying files to S3.

I'll create an
[image](s3/image.png)
file and an S3 bucket,
and then upload the image file to the S3 bucket.

#### Creating an Image

    $ cat <<EOF | pbmtext | pnmmargin -back 1 | pnmmargin -white 1 | pnmtopng > s3/image.png
    PubCloud 2020
    Hands-on Exercise 3
    Image File Stored in AWS S3
    (C) 2020 Erik Auerswald
    EOF
    $ file s3/image.png
    s3/image.png: PNG image data, 208 x 94, 1-bit grayscale, non-interlaced

#### Creating an S3 Bucket

    $ aws s3 ls
    $ aws s3 mb s3://pubcloud2020-website-auerswal
    make_bucket: pubcloud2020-website-auerswal
    $ aws s3 ls
    2020-04-13 16:54:30 pubcloud2020-website-auerswal

#### Copying the Image to the Bucket

    $ aws s3 cp s3/image.png s3://pubcloud2020-website-auerswal/ --acl public-read
    upload: s3/image.png to s3://pubcloud2020-website-auerswal/image.png

This S3 bucket is not yet public,
I will change this later
when enabling the static website feature.

### 4. Enable Static Web Site Hosting on the S3 Bucket

An S3 bucket can be used to
[host a static website](https://docs.aws.amazon.com/AmazonS3/latest/dev/WebsiteHosting.html).
The bucket name will be part of the URL,
as will be the AWS region.
The bucket needs to allow public read access.
All files in the bucket that are part of the website
need to have read permissions for anyone.

I'll add a simple
[`index.html`](s3/index.html)
file that references the image to the bucket,
and use that as the start page.

While the `aws s3` commands provide simple S3 access,
to control public access to an S3 bucket the
`aws s3api` commands are used.
Sadly, the AWS CLI version from Ubuntu 18.04 does not provide the
`...-public-access-block` subcommands needed for this functionality.

Activating the static website feature of the S3 bucket should not
result in a publicly accessible website,
since the default S3 bucket access controls prevent this.

    $ aws s3 cp s3/index.html s3://pubcloud2020-website-auerswal/ --acl public-read
    upload: s3/index.html to s3://pubcloud2020-website-auerswal/index.html
    $ aws s3 ls pubcloud2020-website-auerswal
    2020-04-13 16:58:18        644 image.png
    2020-04-13 18:16:12        470 index.html
    $ aws s3 website s3://pubcloud2020-website-auerswal --index-document index.html
    $ aws s3api get-bucket-website --bucket pubcloud2020-website-auerswal
    ----------------------------
    |     GetBucketWebsite     |
    +--------------------------+
    ||      IndexDocument     ||
    |+---------+--------------+|
    ||  Suffix |  index.html  ||
    |+---------+--------------+|

The website should reside at the URL
http://pubcloud2020-website-auerswal.s3-website.eu-central-1.amazonaws.com
according to the AWS CLI help.
With public access blocked,
requesting this URL results in a 403 error:

    $ lynx -dump http://pubcloud2020-website-auerswal.s3-website.eu-central-1.amazonaws.com
                                     403 Forbidden
    
         * Code: AccessDenied
         * Message: Access Denied
         * RequestId: 4481B7C0844DBE34
         * HostId:
           btWaar93FmOYDOGy5d2s1R4gmMNwys4C7ewAw/VdT5wZqta8TaIHnETUcGOfoFk5+PC
           8Gy21jDY=
         __________________________________________________________________

Since my AWS CLI version does not provide the needed functionality to enable
public access to the S3 bucket,
I will cheat and do this via the
[AWS Management Console](https://portal.aws.amazon.com/)
(the web frontend).
The *Block Public Access* feature is enabled by default on both the account
and bucket levels.
It needs to be disabled on both to allow public access.
After disabling *Block Public Access* a
[bucket policy](s3-access-policy.json)
that grants public read
access needs to be added.
Now the S3 hosted static website is accessible:

    $ lynx -dump http://pubcloud2020-website-auerswal.s3-website.eu-central-1.amazonaws.com
                     PubCloud 2020 - Exercise 3 - Static S3 Website
    
       This website is part of my solution to hands-on exercise 3 of the
       [1]Networking in Public Cloud Deployments course in the spring of 2020.
    
       The exercise requires hosting of an image: PubCloud 2020 Hands-on
       Exercise 3 Image File Stored in AWS S3 (C) 2020 Erik Auerswald
    
    References
    
       1. https://www.ipspace.net/PubCloud/

I'll disable public access again for now.
Since I want to use Terraform,
I'll delete the manually created bucket:

    $ aws s3 ls
    2020-04-13 19:05:20 pubcloud2020-website-auerswal
    $ aws s3 ls s3://pubcloud2020-website-auerswal
    2020-04-13 16:58:18        644 image.png
    2020-04-13 18:55:40        547 index.html
    $ aws s3 rb s3://pubcloud2020-website-auerswal --force
    delete: s3://pubcloud2020-website-auerswal/index.html
    delete: s3://pubcloud2020-website-auerswal/image.png
    remove_bucket: pubcloud2020-website-auerswal
    $ aws s3 ls
    $

### 5. Install and Enable a Web Server on the VM

I want to use
[cloud-init](https://cloud-init.io/)
for server provisioning.
This includes installing package updates
(on Debian or Ubuntu that would basically mean `apt update` and `apt upgrade`),
installing the specific package(s) needed for the service
(`apt install apache2`),
and applying the specific service configuration,
e.g., installing the correct `/var/www/index.html` file.

On Debian and Ubuntu, installed services are started automatically
(sometimes there is a file in `/etc/defaults` that allows disabling
or even requires enabling of a service,
but that is service specific),
Red Hat and derivatives usually require *enabling* of installed services.
Thus Amazon Linux 2 might require this extra step, too.

According to the
[cloud-init documentation](https://cloudinit.readthedocs.io/)
this should be possible with a *cloud-config* file
provided to the EC2 instance via *user-data*.
For installation of Apache this could look as follows:

    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - apache2
    # /var/www/index.html creation missing

### 6. Add a Static Web Page Referencing the S3 Bucket

Providing the `index.html` file might be possible with one of two approaches:

1. Use the `write_files:` directive to create `/var/www/index.html`
2. Use the `runcmd:` directive with `echo`, `printf`, or `cat`

#### 1. Using `write_files:`

I would prefer the first method,
but do not know if it works.
This depends on the execution order of package installation and file creation.
The `apache` package of Debian or Ubuntu installs a default start page,
and I think this is `/var/www/index.html`.
The `/var/www/` directory is created by the `apache2` package,
I do not know if cloud-init automatically creates the path to the file
that is written with `write_files:`.
Sufficiently current versions of cloud-init support Jinja2 templating.
This needs to be activated for the cloud-config file.
This could be used for the optional part of the exercise,
i.e., to add IP address information to the web page.
Relevant instance metadata might include:

* v1.local\_hostname
* v1.region
* v1.availability\_zone
* ds.meta\_data.local\_ipv4

This could look as follows:

    ## template: jinja
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - apache2
    write_files:
      - path: /var/www/index.html
      - owner: 'root:root'
      - permissions: '0644'
      - content: |
          <html>
          <head>
           <title>PubCloud 2020 - Exercise 3 - Static EC2 Website</title>
          </head>
          <body>
           <h1>PubCloud 2020 - Exercise 3 - Static EC2 Website</h1>
           <p>This website is part of my solution to hands-on exercise 3
              of the <a href="https://www.ipspace.net/PubCloud/">Networking
              in Public Cloud Deployments</a> course in the spring of 2020.</p>
           <p>The following image is hosted as a static website on S3:</p>
           <p><img src="http://pubcloud2020-website-auerswal.s3-website.eu-central-1.amazonaws.com/image.png"
                   alt="image stored in S3 bucket"></p>
           <p>This request was served from host {{v1.local_hostname}} with
              local IP address {{ds.meta_data.local_ipv4}} in availability
              zone {{v1.availability_zone}} of region {{v1.region}},
              </p>
          </body>
          </html>

#### 2. Using `runcmd:`

I have seen a cloud-init screencast that used `runcmd:` to generate
the Apache `index.html` file,
so the second method should work.
The `runcmd:` method could include output from iproute2
for the optional part of this exercise,
but instead I'd first try to use instance metadata.
A cloud-config file could look as follows:

    ## template: jinja
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - apache2
    runcmd:
      - |
        cat <<EOF >/var/www/index.html
        <html>
        <head>
         <title>PubCloud 2020 - Exercise 3 - Static EC2 Website</title>
        </head>
        <body>
         <h1>PubCloud 2020 - Exercise 3 - Static EC2 Website</h1>
         <p>This website is part of my solution to hands-on exercise 3
            of the <a href="https://www.ipspace.net/PubCloud/">Networking
            in Public Cloud Deployments</a> course in the spring of 2020.</p>
         <p>The following image is hosted as a static website on S3:</p>
         <p><img src="http://pubcloud2020-website-auerswal.s3-website.eu-central-1.amazonaws.com/image.png"
                 alt="image stored in S3 bucket"></p>
         <p>This request was served from host {{v1.local_hostname}} with
            local IP address {{ds.meta_data.local_ipv4}} in availability
            zone {{v1.availability_zone}} of region {{v1.region}},
            </p>
        </body>
        </html>
        EOF

### 7. Add the Web Server's IP to the Web Page

Adding the server's IP address is already part of the above cloud-config
examples.

The above cloud-configs have been written from looking at documentation
and small examples.
I do not know if they actually work,
but they illustrate what I will try do.

The following section will describe a Terraform configuration
that implements the solution.

## Terraform Solution

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
