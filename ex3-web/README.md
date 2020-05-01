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
That would result in a static webseite hosted on AWS, though.

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

If you do not want to read about all the tedious details,
you can skip ahead to the
[Terraform section](#terraform-solution).

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

```
$ aws ec2 describe-key-pairs
------------------
|DescribeKeyPairs|
+----------------+
```
```
$ aws ec2 describe-key-pairs --output json
{
      "KeyPairs": []
}
```

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

```
$ ssh-keygen -l -E md5 -f pubcloud2020_rsa_id.pub
4096 MD5:a6:a4:be:a2:7a:b5:bd:74:f6:75:7e:66:22:ad:22:ac auerswald@<redacted> (RSA)
```
```
$ awk '{print $2}' pubcloud2020_rsa_id.pub | base64 -d | md5sum
a6a4bea27ab5bd74f6757e6622ad22ac  -
```

A quick web search turns up the answer that AWS uses a different key format
than OpenSSH when calculating the key fingerprint.
To calculate the AWS fingerprint,
the key has to converted to the matching format first, i.e.,
to a DER encoding:

```
$ ssh-keygen -e -m PKCS8 -f pubcloud2020_rsa_id.pub | openssl pkey -pubin -pubout -outform DER | md5sum
bcc0badec12da8385d0833badd18dbc4  -
```
```
$ aws ec2 describe-key-pairs --output text | fgrep PubCloud2020 | cut -f2 | tr -d :
bcc0badec12da8385d0833badd18dbc4
```

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

```
$ aws ec2 delete-key-pair --key-name PubCloud2020
```
```
$ aws ec2 describe-key-pairs
------------------
|DescribeKeyPairs|
+----------------+
```
```
$ aws ec2 describe-key-pairs --output json
{
      "KeyPairs": []
}
```

As far as I understand it the default security group used for the default VPC
does not allow SSH access.
Thus I expect to need to either update the default security group,
or create a suitable security group as well.

**Update 2020-04-20:** Instead of using the AWS Key Pair functionality,
using cloud-init (see below) could be used to manage public SSH keys.
Cloud-init is not limited to RSA Keys, as far as I know.

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

```
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
```
```
$ aws ec2 authorize-security-group-ingress --group-name default --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "SSH access from the Internet"}]}, {"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "HTTP access from the Internet"}]}, {"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "HTTPS access from the Internet"}]}]'
```
```
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
```
```
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
```
```
$ aws ec2 revoke-security-group-ingress --group-name default --protocol tcp --port 22 --cidr 0.0.0.0/0
```
```
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
```
```
$ aws ec2 revoke-security-group-ingress --group-name default --protocol tcp --port 80 --cidr 0.0.0.0/0
```
```
$ aws ec2 revoke-security-group-ingress --group-name default --protocol tcp --port 443 --cidr 0.0.0.0/0
```
```
$ aws ec2 describe-security-groups --output text
SECURITYGROUPS  default VPC security group      sg-805b23e7     default 143440624024    vpc-7f13dc15
IPPERMISSIONS   -1
USERIDGROUPPAIRS        sg-805b23e7     143440624024
IPPERMISSIONSEGRESS     -1
IPRANGES        0.0.0.0/0
```

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
Amazon S3 buckets have the peculiar characteristic that their names must
be globally unique.
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

```
$ cat <<EOF | pbmtext | pnmmargin -back 1 | pnmmargin -white 1 | pnmtopng > s3/image.png
PubCloud 2020
Hands-on Exercise 3
Image File Stored in AWS S3
(C) 2020 Erik Auerswald
EOF
```
```
$ file s3/image.png
s3/image.png: PNG image data, 208 x 94, 1-bit grayscale, non-interlaced
```

#### Creating an S3 Bucket

```
$ aws s3 ls
```
```
$ aws s3 mb s3://pubcloud2020-website-auerswal
make_bucket: pubcloud2020-website-auerswal
```
```
$ aws s3 ls
2020-04-13 16:54:30 pubcloud2020-website-auerswal
```

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

```
$ aws s3 cp s3/index.html s3://pubcloud2020-website-auerswal/ --acl public-read
upload: s3/index.html to s3://pubcloud2020-website-auerswal/index.html
```
```
$ aws s3 ls pubcloud2020-website-auerswal
2020-04-13 16:58:18        644 image.png
2020-04-13 18:16:12        470 index.html
```
```
$ aws s3 website s3://pubcloud2020-website-auerswal --index-document index.html
```
```
$ aws s3api get-bucket-website --bucket pubcloud2020-website-auerswal
----------------------------
|     GetBucketWebsite     |
+--------------------------+
||      IndexDocument     ||
|+---------+--------------+|
||  Suffix |  index.html  ||
|+---------+--------------+|
```

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

```
$ aws s3 ls
2020-04-13 19:05:20 pubcloud2020-website-auerswal
```
```
$ aws s3 ls s3://pubcloud2020-website-auerswal
2020-04-13 16:58:18        644 image.png
2020-04-13 18:55:40        547 index.html
```
```
$ aws s3 rb s3://pubcloud2020-website-auerswal --force
delete: s3://pubcloud2020-website-auerswal/index.html
delete: s3://pubcloud2020-website-auerswal/image.png
remove_bucket: pubcloud2020-website-auerswal
```
```
$ aws s3 ls
```

### 5. Install and Enable a Web Server on the VM

I want to use
[cloud-init](https://cloud-init.io/)
for server provisioning.
This includes installing package updates
(on Debian or Ubuntu that would basically mean `apt update` and `apt upgrade`),
installing the specific package(s) needed for the service
(`apt install apache2`),
and applying the specific service configuration,
e.g., installing the correct `/var/www/html/index.html` file.

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
    # /var/www/html/index.html creation missing

### 6. Add a Static Web Page Referencing the S3 Bucket

Providing the `index.html` file might be possible with one of two approaches:

1. Use the `write_files:` directive to create `/var/www/html/index.html`
2. Use the `runcmd:` directive with `echo`, `printf`, or `cat`

#### 1. Using `write_files:`

I would prefer the first method,
but do not know if it works.
This depends on the execution order of package installation and file creation.
The `apache` package of Debian or Ubuntu installs a default start page,
and I think this is `/var/www/html/index.html`.
The `/var/www/html/` directory is created by the `apache2` package,
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
      - path: /var/www/html/index.html
        owner: 'root:root'
        permissions: '0644'
        content: |
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
        cat <<EOF >/var/www/html/index.html
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

I want to create a
[Terraform](https://www.terraform.io/)
configuration for the web server deployment.

### Avoiding the Default Security Group

This configuration needs to comprise all used components,
including VPC and Security Group (SG).
The exercise specifies to use the default VPC,
but does not prescribe which Subnet or Security Group to use.
Since Terraform
[does not restore](https://www.terraform.io/docs/providers/aws/r/default_security_group.html#removing-aws_default_security_group-from-your-configuration)
the Default Security Group when destroying the deployment,
I will create a new Security Group for the web server.

### The Terraform Configuration

The Terraform configuration for the web server deployment can be found
in the
[web\_server.tf](terraform/web_server.tf)
file.
I will check in and show the final version only.

I use the same version of the Terraform AWS provider as in the
[previous](../ex2-iac/)
hands-on exercise.

I use variable definitions to select the GNU/Linux flavor:
the file
[ubuntu.tfvars](terraform/ubuntu.tfvars)
selects the latest Ubuntu 18.04 LTS image,
the file
[amazon\_linux\_2.tfvars](terraform/amazon_linux_2.tfvars)
selects the latest Amazon Linux 2 image.
The variables are used for the *aws_ami* data source
that selects the Amazon Machine Image (AMI) to use for the web server.

The web server shall be deployed in the default VPC.
Thus the default VPC is added as a data source.
This data source is used to add the new Security Group to the default VPC.

The public SSH key for EC2 instance access is added as a resource,
reading the actual public key from the file system using Terraform's
*file()* function.

The per account *S3 Public Access Block* is added as a resource.
I do not really understand the pertaining Terraform
[documentation](https://www.terraform.io/docs/providers/aws/r/s3_account_public_access_block.html),
thus I will probably need to apply a *trial and error* methodology.
According to the documentation every blocking action of this resource
defaults to *false*,
and I just want to disable the block,
thus I assume that I do not need to configure anything,
just define this resource.

The the S3 bucket is added as a resource.
The static website functionality for the bucket is enabled in this resource.
The two files needed for the S3 static website are added via
*aws_s3_bucket_object* resources.
The *etag* argument allows Terraform to detect changes of the local files.

Since I do not want to change the default SG via Terraform,
I add a new one just for the web server.
This SG is attached to the default VPC,
referenced via Terraform *data source*,
since I do not want to change the default VPC itself.
The SG replicates adding SSH and HTTP(S) access to the default SG.

The final resource is the web server EC2 instance.
I have added manual dependencies on the S3 bucket and its contents,
since the website references the image stored in the S3 bucket,
but Terraform cannot determine this itself.
The *cloud-config* for *cloud-init* is read from the file
[web\_server.cloud-config](terraform/web_server.cloud-config)
and provided as *user_data*.

I want to have the web server's public DNS name and public IP address
as outputs.
Additionally, I want to have S3 website information as outputs.

### Invoking Terraform

At first, the Terraform working directory needs to be initialized
using `terraform init`:

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

Then I update the formatting of the HCL configuration file using
`terraform fmt`:

    $ terraform fmt
    amazon_linux_2.tfvars
    ubuntu.tfvars
    web_server.tf

I then use `terraform validate` to check mys configuration.
After fixing a couple of mistakes
and re-running `terraform fmt`
the configuration is accepted:

```
$ terraform validate

Error: Unsupported block type
[...further output omitted]
```
```
$ vi web_server.tf
```
```
$ terraform fmt
web_server.tf
```
```
$ terraform validate
Success! The configuration is valid.

```

Now I feel sufficiently confident to try and instantiate the Terraform
configuration using `terraform apply`.
Terraform will show what it intends to do,
and requires confirmation,
so I can still abort if I do not like what I see.

The initial configuration did not work.
I did not set the content type for the S3 objects,
so the web server returned them as `binary/octet-stream`.
As a result web browsers did not show them as web page and image,
but provided them as downloads.
Additionally, I wrote the index document to the wrong path,
and used a faulty `write_files:` directive,
which resulted in an empty file.
I have corercted those problems above as well,
because I want to use this page as a reference.

So after troubleshooting I use `terraform destroy`
to clean up.
I then fix the configuration and try again:

```
$ terraform validate
Success! The configuration is valid.

```
```
$ terraform apply --var-file ubuntu.tfvars 
data.aws_vpc.default: Refreshing state...
data.aws_ami.gnu_linux_image: Refreshing state...

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.ec2_web will be created
  + resource "aws_instance" "ec2_web" {
      + ami                          = "ami-0e342d72b12109f91"
      + arn                          = (known after apply)
      + associate_public_ip_address  = true
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
          + "Name" = "Web_Server_EC2_Instance"
        }
      + tenancy                      = (known after apply)
      + user_data                    = "455b1285756944477f035f285dceb37708d98635"
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

  # aws_key_pair.course_ssh_key will be created
  + resource "aws_key_pair" "course_ssh_key" {
      + fingerprint = (known after apply)
      + id          = (known after apply)
      + key_name    = "tf-pubcloud2020"
      + key_pair_id = (known after apply)
      + public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDiXuVGxn6zqLCPKbcojNC813FAnOPBWToBz/XTQaMzMsoAeKMRwVrUoyHEVj8UTFiuEUbTz/0jHItv5ZmFXI1DNY1m+hXxCDVcBp8ojCutX3+AJ012qG2PIZaloaYCjrTkhHj9VmMHAl1jzJ0EbPsoU/Qc4pZCNUNaCVCkG6EHisOUy9wx20i4gA/nrDnjIxk9TD2mGdlVCK7SESH/vGWgMtU6fLI65trtC4eojPNNUyMq8tTLyJxoTdYEwMY5alKkcjjw6+yVBOrtYgZSlMW02WLTkJT7eCxwVHig8a+bywiwAxuvYlUgfmOHEGEIXXTGk/+KNiLrDXdmkK4kuUvlf6rD7qR/kedqQAt0k5v/PiW3ufpej7n1ZBZroSsBT/0Yp5UcCLxpzskUYu+TRLRp+6gI50KsNe/oT8tesNtOVTK2ePD4eXApXAYwQpXy1389c4gGgh4wWljmHyeoFjcd4Soq847/PNspRdswR/u5jyswTsCROKsCJ4+whJRme8JoqaZHGBTpTu9n6gaZJVXbFM/55RYh0bpuCD5BHrdk0+HX4BmhJ1KqdDTDR84y2riwlpv6Eiw8AX8N2GVLOpP6RMt/AUCNUEy5nPWJosKb+UQE/j1dRJ9iorm2EGbh30dv/nRCb2Cu7BVyNWbmSrVaKdJub28SfV5L51sd+ATBw== auerswald@short"
    }

  # aws_s3_account_public_access_block.s3_pab will be created
  + resource "aws_s3_account_public_access_block" "s3_pab" {
      + account_id              = (known after apply)
      + block_public_acls       = false
      + block_public_policy     = false
      + id                      = (known after apply)
      + ignore_public_acls      = false
      + restrict_public_buckets = false
    }

  # aws_s3_bucket.s3_image will be created
  + resource "aws_s3_bucket" "s3_image" {
      + acceleration_status         = (known after apply)
      + acl                         = "public-read"
      + arn                         = (known after apply)
      + bucket                      = "pubcloud2020-ex3-website-auerswal"
      + bucket_domain_name          = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = false
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + policy                      = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "s3:GetObject"
                      + Effect    = "Allow"
                      + Principal = "*"
                      + Resource  = "arn:aws:s3:::pubcloud2020-ex3-website-auerswal/*"
                      + Sid       = "PublicReadGetObject"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + region                      = (known after apply)
      + request_payer               = (known after apply)
      + tags                        = {
          + "Name" = "S3_bucket_for_image"
        }
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)

      + versioning {
          + enabled    = (known after apply)
          + mfa_delete = (known after apply)
        }

      + website {
          + index_document = "index.html"
        }
    }

  # aws_s3_bucket_object.image will be created
  + resource "aws_s3_bucket_object" "image" {
      + acl                    = "public-read"
      + bucket                 = (known after apply)
      + content_type           = "image/png"
      + etag                   = "fcee1e0ebd394059c359e15bbd2b566e"
      + force_destroy          = false
      + id                     = (known after apply)
      + key                    = "image.png"
      + server_side_encryption = (known after apply)
      + source                 = "../s3/image.png"
      + storage_class          = (known after apply)
      + version_id             = (known after apply)
    }

  # aws_s3_bucket_object.index will be created
  + resource "aws_s3_bucket_object" "index" {
      + acl                    = "public-read"
      + bucket                 = (known after apply)
      + content_type           = "text/html"
      + etag                   = "fedc37a095b63326f321a4b0562a44af"
      + force_destroy          = false
      + id                     = (known after apply)
      + key                    = "index.html"
      + server_side_encryption = (known after apply)
      + source                 = "../s3/index.html"
      + storage_class          = (known after apply)
      + version_id             = (known after apply)
    }

  # aws_security_group.sg_web will be created
  + resource "aws_security_group" "sg_web" {
      + arn                    = (known after apply)
      + description            = "Allow HTTP(S) and SSH access to web server"
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
      + name                   = "tf-sg-web"
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name" = "Web_Server_Security_Group"
        }
      + vpc_id                 = "vpc-7f13dc15"
    }

Plan: 7 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_s3_account_public_access_block.s3_pab: Creating...
aws_key_pair.course_ssh_key: Creating...
aws_security_group.sg_web: Creating...
aws_s3_bucket.s3_image: Creating...
aws_key_pair.course_ssh_key: Creation complete after 1s [id=tf-pubcloud2020]
aws_s3_account_public_access_block.s3_pab: Creation complete after 2s [id=143440624024]
aws_security_group.sg_web: Creation complete after 4s [id=sg-0416ee04e11283b99]
aws_s3_bucket.s3_image: Creation complete after 9s [id=pubcloud2020-ex3-website-auerswal]
aws_s3_bucket_object.index: Creating...
aws_s3_bucket_object.image: Creating...
aws_s3_bucket_object.image: Creation complete after 1s [id=image.png]
aws_s3_bucket_object.index: Creation complete after 1s [id=index.html]
aws_instance.ec2_web: Creating...
aws_instance.ec2_web: Still creating... [10s elapsed]
aws_instance.ec2_web: Still creating... [20s elapsed]
aws_instance.ec2_web: Creation complete after 30s [id=i-0a45886aa3298662a]

Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

s3_endpoint = pubcloud2020-ex3-website-auerswal.s3-website.eu-central-1.amazonaws.com
s3_url = s3-website.eu-central-1.amazonaws.com
web_server_ip = 18.194.233.230
web_server_name = ec2-18-194-233-230.eu-central-1.compute.amazonaws.com
```

The static S3 web site works:

```
$ lynx -dump http://pubcloud2020-ex3-website-auerswal.s3-website.eu-central-1.amazonaws.com/
                 PubCloud 2020 - Exercise 3 - Static S3 Website

   This website is part of my solution to hands-on exercise 3 of the
   [1]Networking in Public Cloud Deployments course in the spring of 2020.

   The exercise requires hosting of an image: PubCloud 2020 Hands-on
   Exercise 3 Image File Stored in AWS S3 (C) 2020 Erik Auerswald

References

   1. https://www.ipspace.net/PubCloud/
```
```
$ wget -q -O- http://pubcloud2020-ex3-website-auerswal.s3-website.eu-central-1.amazonaws.com/image.png | md5sum
fcee1e0ebd394059c359e15bbd2b566e  -
```
```
$ md5sum image.png
fcee1e0ebd394059c359e15bbd2b566e  image.png
```

The EC2 instance needs some time to start,
install system updates,
and install and configure the web server.
After a short while the website is available:

```
$ lynx -dump http://ec2-18-194-233-230.eu-central-1.compute.amazonaws.com
                PubCloud 2020 - Exercise 3 - Static EC2 Website

   This website is part of my solution to hands-on exercise 3 of the
   [1]Networking in Public Cloud Deployments course in the spring of 2020.

   The following image is hosted as a static website on S3:

   image stored in S3 bucket

   This request was served from host ip-172-31-43-50 with local IP address
   172.31.43.50 in availability zone eu-central-1b of region eu-central-1.

References

   1. https://www.ipspace.net/PubCloud/
```

The default Apache configuration does not include HTTPS:

```
$ telnet ec2-18-194-233-230.eu-central-1.compute.amazonaws.com 443
Trying 18.194.233.230...
telnet: Unable to connect to remote host: Connection refused
```

I remove the web server deployment using `terraform destroy`:

```
$ terraform destroy --var-file ubuntu.tfvars
aws_key_pair.course_ssh_key: Refreshing state... [id=tf-pubcloud2020]
aws_s3_account_public_access_block.s3_pab: Refreshing state... [id=143440624024]
data.aws_ami.gnu_linux_image: Refreshing state...
data.aws_vpc.default: Refreshing state...
aws_s3_bucket.s3_image: Refreshing state... [id=pubcloud2020-ex3-website-auerswal]
aws_security_group.sg_web: Refreshing state... [id=sg-0416ee04e11283b99]
aws_s3_bucket_object.image: Refreshing state... [id=image.png]
aws_s3_bucket_object.index: Refreshing state... [id=index.html]
aws_instance.ec2_web: Refreshing state... [id=i-0a45886aa3298662a]

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # aws_instance.ec2_web will be destroyed
  - resource "aws_instance" "ec2_web" {
      - ami                          = "ami-0e342d72b12109f91" -> null
      - arn                          = "arn:aws:ec2:eu-central-1:143440624024:instance/i-0a45886aa3298662a" -> null
      - associate_public_ip_address  = true -> null
      - availability_zone            = "eu-central-1b" -> null
      - cpu_core_count               = 1 -> null
      - cpu_threads_per_core         = 1 -> null
      - disable_api_termination      = false -> null
      - ebs_optimized                = false -> null
      - get_password_data            = false -> null
      - hibernation                  = false -> null
      - id                           = "i-0a45886aa3298662a" -> null
      - instance_state               = "running" -> null
      - instance_type                = "t2.micro" -> null
      - ipv6_address_count           = 0 -> null
      - ipv6_addresses               = [] -> null
      - key_name                     = "tf-pubcloud2020" -> null
      - monitoring                   = false -> null
      - primary_network_interface_id = "eni-0e241c9f13d9e496a" -> null
      - private_dns                  = "ip-172-31-43-50.eu-central-1.compute.internal" -> null
      - private_ip                   = "172.31.43.50" -> null
      - public_dns                   = "ec2-18-194-233-230.eu-central-1.compute.amazonaws.com" -> null
      - public_ip                    = "18.194.233.230" -> null
      - security_groups              = [
          - "tf-sg-web",
        ] -> null
      - source_dest_check            = true -> null
      - subnet_id                    = "subnet-e7d63b9b" -> null
      - tags                         = {
          - "Name" = "Web_Server_EC2_Instance"
        } -> null
      - tenancy                      = "default" -> null
      - user_data                    = "455b1285756944477f035f285dceb37708d98635" -> null
      - volume_tags                  = {} -> null
      - vpc_security_group_ids       = [
          - "sg-0416ee04e11283b99",
        ] -> null

      - credit_specification {
          - cpu_credits = "standard" -> null
        }

      - root_block_device {
          - delete_on_termination = true -> null
          - encrypted             = false -> null
          - iops                  = 100 -> null
          - volume_id             = "vol-09085a84b1985f02d" -> null
          - volume_size           = 8 -> null
          - volume_type           = "gp2" -> null
        }
    }

  # aws_key_pair.course_ssh_key will be destroyed
  - resource "aws_key_pair" "course_ssh_key" {
      - fingerprint = "bc:c0:ba:de:c1:2d:a8:38:5d:08:33:ba:dd:18:db:c4" -> null
      - id          = "tf-pubcloud2020" -> null
      - key_name    = "tf-pubcloud2020" -> null
      - key_pair_id = "key-092ae5a297fdd1019" -> null
      - public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDiXuVGxn6zqLCPKbcojNC813FAnOPBWToBz/XTQaMzMsoAeKMRwVrUoyHEVj8UTFiuEUbTz/0jHItv5ZmFXI1DNY1m+hXxCDVcBp8ojCutX3+AJ012qG2PIZaloaYCjrTkhHj9VmMHAl1jzJ0EbPsoU/Qc4pZCNUNaCVCkG6EHisOUy9wx20i4gA/nrDnjIxk9TD2mGdlVCK7SESH/vGWgMtU6fLI65trtC4eojPNNUyMq8tTLyJxoTdYEwMY5alKkcjjw6+yVBOrtYgZSlMW02WLTkJT7eCxwVHig8a+bywiwAxuvYlUgfmOHEGEIXXTGk/+KNiLrDXdmkK4kuUvlf6rD7qR/kedqQAt0k5v/PiW3ufpej7n1ZBZroSsBT/0Yp5UcCLxpzskUYu+TRLRp+6gI50KsNe/oT8tesNtOVTK2ePD4eXApXAYwQpXy1389c4gGgh4wWljmHyeoFjcd4Soq847/PNspRdswR/u5jyswTsCROKsCJ4+whJRme8JoqaZHGBTpTu9n6gaZJVXbFM/55RYh0bpuCD5BHrdk0+HX4BmhJ1KqdDTDR84y2riwlpv6Eiw8AX8N2GVLOpP6RMt/AUCNUEy5nPWJosKb+UQE/j1dRJ9iorm2EGbh30dv/nRCb2Cu7BVyNWbmSrVaKdJub28SfV5L51sd+ATBw== auerswald@short" -> null
      - tags        = {} -> null
    }

  # aws_s3_account_public_access_block.s3_pab will be destroyed
  - resource "aws_s3_account_public_access_block" "s3_pab" {
      - account_id              = "143440624024" -> null
      - block_public_acls       = false -> null
      - block_public_policy     = false -> null
      - id                      = "143440624024" -> null
      - ignore_public_acls      = false -> null
      - restrict_public_buckets = false -> null
    }

  # aws_s3_bucket.s3_image will be destroyed
  - resource "aws_s3_bucket" "s3_image" {
      - acl                         = "public-read" -> null
      - arn                         = "arn:aws:s3:::pubcloud2020-ex3-website-auerswal" -> null
      - bucket                      = "pubcloud2020-ex3-website-auerswal" -> null
      - bucket_domain_name          = "pubcloud2020-ex3-website-auerswal.s3.amazonaws.com" -> null
      - bucket_regional_domain_name = "pubcloud2020-ex3-website-auerswal.s3.eu-central-1.amazonaws.com" -> null
      - force_destroy               = false -> null
      - hosted_zone_id              = "Z21DNDUVLTQW6Q" -> null
      - id                          = "pubcloud2020-ex3-website-auerswal" -> null
      - policy                      = jsonencode(
            {
              - Statement = [
                  - {
                      - Action    = "s3:GetObject"
                      - Effect    = "Allow"
                      - Principal = "*"
                      - Resource  = "arn:aws:s3:::pubcloud2020-ex3-website-auerswal/*"
                      - Sid       = "PublicReadGetObject"
                    },
                ]
              - Version   = "2012-10-17"
            }
        ) -> null
      - region                      = "eu-central-1" -> null
      - request_payer               = "BucketOwner" -> null
      - tags                        = {
          - "Name" = "S3_bucket_for_image"
        } -> null
      - website_domain              = "s3-website.eu-central-1.amazonaws.com" -> null
      - website_endpoint            = "pubcloud2020-ex3-website-auerswal.s3-website.eu-central-1.amazonaws.com" -> null

      - versioning {
          - enabled    = false -> null
          - mfa_delete = false -> null
        }

      - website {
          - index_document = "index.html" -> null
        }
    }

  # aws_s3_bucket_object.image will be destroyed
  - resource "aws_s3_bucket_object" "image" {
      - acl           = "public-read" -> null
      - bucket        = "pubcloud2020-ex3-website-auerswal" -> null
      - content_type  = "image/png" -> null
      - etag          = "fcee1e0ebd394059c359e15bbd2b566e" -> null
      - force_destroy = false -> null
      - id            = "image.png" -> null
      - key           = "image.png" -> null
      - metadata      = {} -> null
      - source        = "../s3/image.png" -> null
      - storage_class = "STANDARD" -> null
      - tags          = {} -> null
    }

  # aws_s3_bucket_object.index will be destroyed
  - resource "aws_s3_bucket_object" "index" {
      - acl           = "public-read" -> null
      - bucket        = "pubcloud2020-ex3-website-auerswal" -> null
      - content_type  = "text/html" -> null
      - etag          = "fedc37a095b63326f321a4b0562a44af" -> null
      - force_destroy = false -> null
      - id            = "index.html" -> null
      - key           = "index.html" -> null
      - metadata      = {} -> null
      - source        = "../s3/index.html" -> null
      - storage_class = "STANDARD" -> null
      - tags          = {} -> null
    }

  # aws_security_group.sg_web will be destroyed
  - resource "aws_security_group" "sg_web" {
      - arn                    = "arn:aws:ec2:eu-central-1:143440624024:security-group/sg-0416ee04e11283b99" -> null
      - description            = "Allow HTTP(S) and SSH access to web server" -> null
      - egress                 = [
          - {
              - cidr_blocks      = [
                  - "0.0.0.0/0",
                ]
              - description      = "Allow Internet access for, e.g., updates"
              - from_port        = 0
              - ipv6_cidr_blocks = []
              - prefix_list_ids  = []
              - protocol         = "-1"
              - security_groups  = []
              - self             = false
              - to_port          = 0
            },
        ] -> null
      - id                     = "sg-0416ee04e11283b99" -> null
      - ingress                = [
          - {
              - cidr_blocks      = [
                  - "0.0.0.0/0",
                ]
              - description      = "Allow HTTP from the Internet"
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
              - description      = "Allow HTTPS from the Internet"
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
              - description      = "Allow SSH from the Internet"
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
      - name                   = "tf-sg-web" -> null
      - owner_id               = "143440624024" -> null
      - revoke_rules_on_delete = false -> null
      - tags                   = {
          - "Name" = "Web_Server_Security_Group"
        } -> null
      - vpc_id                 = "vpc-7f13dc15" -> null
    }

Plan: 0 to add, 0 to change, 7 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

aws_s3_account_public_access_block.s3_pab: Destroying... [id=143440624024]
aws_instance.ec2_web: Destroying... [id=i-0a45886aa3298662a]
aws_s3_account_public_access_block.s3_pab: Destruction complete after 1s
aws_instance.ec2_web: Still destroying... [id=i-0a45886aa3298662a, 10s elapsed]
aws_instance.ec2_web: Still destroying... [id=i-0a45886aa3298662a, 20s elapsed]
aws_instance.ec2_web: Destruction complete after 28s
aws_key_pair.course_ssh_key: Destroying... [id=tf-pubcloud2020]
aws_s3_bucket_object.image: Destroying... [id=image.png]
aws_s3_bucket_object.index: Destroying... [id=index.html]
aws_security_group.sg_web: Destroying... [id=sg-0416ee04e11283b99]
aws_key_pair.course_ssh_key: Destruction complete after 0s
aws_s3_bucket_object.index: Destruction complete after 0s
aws_s3_bucket_object.image: Destruction complete after 0s
aws_s3_bucket.s3_image: Destroying... [id=pubcloud2020-ex3-website-auerswal]
aws_security_group.sg_web: Destruction complete after 1s
aws_s3_bucket.s3_image: Destruction complete after 0s

Destroy complete! Resources: 7 destroyed.
```

Then I verify via AWS CLI that the cloud resources have been removed:

```
$ aws s3 ls
```
```
$ aws ec2 describe-instances
----------------------------------------------------------------------------
|                             DescribeInstances                            |
+--------------------------------------------------------------------------+
||                              Reservations                              ||
|+-----------------------------+------------------------------------------+|
||  OwnerId                    |  143440624024                            ||
||  ReservationId              |  r-08edc8f571d4aa539                     ||
|+-----------------------------+------------------------------------------+|
|||                               Instances                              |||
||+------------------------+---------------------------------------------+||
|||  AmiLaunchIndex        |  0                                          |||
|||  Architecture          |  x86_64                                     |||
|||  ClientToken           |                                             |||
|||  EbsOptimized          |  False                                      |||
|||  EnaSupport            |  True                                       |||
|||  Hypervisor            |  xen                                        |||
|||  ImageId               |  ami-0e342d72b12109f91                      |||
|||  InstanceId            |  i-0a45886aa3298662a                        |||
|||  InstanceType          |  t2.micro                                   |||
|||  KeyName               |  tf-pubcloud2020                            |||
|||  LaunchTime            |  2020-04-19T19:26:48.000Z                   |||
|||  PrivateDnsName        |                                             |||
|||  PublicDnsName         |                                             |||
|||  RootDeviceName        |  /dev/sda1                                  |||
|||  RootDeviceType        |  ebs                                        |||
|||  StateTransitionReason |  User initiated (2020-04-19 19:45:05 GMT)   |||
|||  VirtualizationType    |  hvm                                        |||
||+------------------------+---------------------------------------------+||
||||                             Monitoring                             ||||
|||+----------------------------+---------------------------------------+|||
||||  State                     |  disabled                             ||||
|||+----------------------------+---------------------------------------+|||
||||                              Placement                             ||||
|||+------------------------------------+-------------------------------+|||
||||  AvailabilityZone                  |  eu-central-1b                ||||
||||  GroupName                         |                               ||||
||||  Tenancy                           |  default                      ||||
|||+------------------------------------+-------------------------------+|||
||||                                State                               ||||
|||+-----------------------+--------------------------------------------+|||
||||  Code                 |  48                                        ||||
||||  Name                 |  terminated                                ||||
|||+-----------------------+--------------------------------------------+|||
||||                             StateReason                            ||||
|||+---------+----------------------------------------------------------+|||
||||  Code   |  Client.UserInitiatedShutdown                            ||||
||||  Message|  Client.UserInitiatedShutdown: User initiated shutdown   ||||
|||+---------+----------------------------------------------------------+|||
||||                                Tags                                ||||
|||+----------------+---------------------------------------------------+|||
||||  Key           |  Name                                             ||||
||||  Value         |  Web_Server_EC2_Instance                          ||||
|||+----------------+---------------------------------------------------+|||
||                              Reservations                              ||
|+-----------------------------+------------------------------------------+|
||  OwnerId                    |  143440624024                            ||
||  ReservationId              |  r-07b3732cbe746f0d0                     ||
|+-----------------------------+------------------------------------------+|
|||                               Instances                              |||
||+------------------------+---------------------------------------------+||
|||  AmiLaunchIndex        |  0                                          |||
|||  Architecture          |  x86_64                                     |||
|||  ClientToken           |                                             |||
|||  EbsOptimized          |  False                                      |||
|||  EnaSupport            |  True                                       |||
|||  Hypervisor            |  xen                                        |||
|||  ImageId               |  ami-0e342d72b12109f91                      |||
|||  InstanceId            |  i-09e2753ebb2dae675                        |||
|||  InstanceType          |  t2.micro                                   |||
|||  KeyName               |  tf-pubcloud2020                            |||
|||  LaunchTime            |  2020-04-19T18:21:25.000Z                   |||
|||  PrivateDnsName        |                                             |||
|||  PublicDnsName         |                                             |||
|||  RootDeviceName        |  /dev/sda1                                  |||
|||  RootDeviceType        |  ebs                                        |||
|||  StateTransitionReason |  User initiated (2020-04-19 19:06:48 GMT)   |||
|||  VirtualizationType    |  hvm                                        |||
||+------------------------+---------------------------------------------+||
||||                             Monitoring                             ||||
|||+----------------------------+---------------------------------------+|||
||||  State                     |  disabled                             ||||
|||+----------------------------+---------------------------------------+|||
||||                              Placement                             ||||
|||+------------------------------------+-------------------------------+|||
||||  AvailabilityZone                  |  eu-central-1b                ||||
||||  GroupName                         |                               ||||
||||  Tenancy                           |  default                      ||||
|||+------------------------------------+-------------------------------+|||
||||                                State                               ||||
|||+-----------------------+--------------------------------------------+|||
||||  Code                 |  48                                        ||||
||||  Name                 |  terminated                                ||||
|||+-----------------------+--------------------------------------------+|||
||||                             StateReason                            ||||
|||+---------+----------------------------------------------------------+|||
||||  Code   |  Client.UserInitiatedShutdown                            ||||
||||  Message|  Client.UserInitiatedShutdown: User initiated shutdown   ||||
|||+---------+----------------------------------------------------------+|||
||||                                Tags                                ||||
|||+----------------+---------------------------------------------------+|||
||||  Key           |  Name                                             ||||
||||  Value         |  Web_Server_EC2_Instance                          ||||
|||+----------------+---------------------------------------------------+|||
```
```
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
```
```
$ aws ec2 describe-security-groups
----------------------------------------------------------------------------------------------
|                                   DescribeSecurityGroups                                   |
+--------------------------------------------------------------------------------------------+
||                                      SecurityGroups                                      ||
|+-----------------------------+--------------+------------+---------------+----------------+|
||         Description         |   GroupId    | GroupName  |    OwnerId    |     VpcId      ||
|+-----------------------------+--------------+------------+---------------+----------------+|
||  default VPC security group |  sg-805b23e7 |  default   |  143440624024 |  vpc-7f13dc15  ||
|+-----------------------------+--------------+------------+---------------+----------------+|
|||                                      IpPermissions                                     |||
||+----------------------------------------------------------------------------------------+||
|||                                       IpProtocol                                       |||
||+----------------------------------------------------------------------------------------+||
|||  -1                                                                                    |||
||+----------------------------------------------------------------------------------------+||
||||                                   UserIdGroupPairs                                   ||||
|||+-----------------------------------------+--------------------------------------------+|||
||||                 GroupId                 |                  UserId                    ||||
|||+-----------------------------------------+--------------------------------------------+|||
||||  sg-805b23e7                            |  143440624024                              ||||
|||+-----------------------------------------+--------------------------------------------+|||
|||                                   IpPermissionsEgress                                  |||
||+----------------------------------------------------------------------------------------+||
|||                                       IpProtocol                                       |||
||+----------------------------------------------------------------------------------------+||
|||  -1                                                                                    |||
||+----------------------------------------------------------------------------------------+||
||||                                       IpRanges                                       ||||
|||+--------------------------------------------------------------------------------------+|||
||||                                        CidrIp                                        ||||
|||+--------------------------------------------------------------------------------------+|||
||||  0.0.0.0/0                                                                           ||||
|||+--------------------------------------------------------------------------------------+|||
```
```
$ aws ec2 describe-key-pairs
------------------
|DescribeKeyPairs|
+----------------+
```

The EC2 instances are still shown,
but in a state of *terminated*.
The other resources are no longer shown at all.

That's all for now,
I won't try out Amazon Linux 2, nginx, or the `runcmd:` cloud-init method yet.

After some time, the instances are gone for good:

    $ aws ec2 describe-instances
    -------------------
    |DescribeInstances|
    +-----------------+

*To stay honest, I have changed the Terraform output to show just the
complete DNS name of the S3 static website.
Again, the Terraform documentation,
while comprehensive,
still shows optimization potential.
I did not care for the `website_domain`,
but rather for the `website_endpoint`.
Thus I removed the `website_domain` from the Terraform configuration outputs.*

**Update 2020-04-23:**
*Destroying* the Terraform configuration that contained S3 Public Access Block
removal did *not* re-instate the block.
S3 buckets can still be opened to the Internet.
This behavior is consistent with Terraform's documented behavior
regarding a VPC's default Security Group.

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
