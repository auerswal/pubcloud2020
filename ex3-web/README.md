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

## Using Amazon Web Services

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
but have not yet decided on which of the two suggested web servers to use.
I have experience with
[Apache](https://httpd.apache.org/),
I have used
[lighttpd](https://www.lighttpd.net/)
in a project,
but have not yet implemented an
[nginx](https://nginx.org/)
installation.

I expect the solution to be one Terraform configuration.
I will try to build it step by step,
but do not yet know how each step will be documented.

## 1. Create an SSH Key Pair

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
If a key pair is created outside of AWS,
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

Then I upload the public key I want to use:

    $ aws ec2 import-key-pair --key-name 'PubCloud2020' --public-key-material file://pubcloud2020_rsa_id.pub
    ---------------------------------------------------------------------
    |                           ImportKeyPair                           |
    +---------------------------------------------------+---------------+
    |                  KeyFingerprint                   |    KeyName    |
    +---------------------------------------------------+---------------+
    |  bc:c0:ba:de:c1:2d:a8:38:5d:08:33:ba:dd:18:db:c4  |  PubCloud2020 |
    +---------------------------------------------------+---------------+

Now there is an SSH *key pair* available for use with EC2 instances:

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

So in the end uploading (*importing*) the existing OpenSSH key did work.
I expect to see the OpenSSH fingerprint for the first login to a new instance,
since I will be using OpenSSH.

I want to use a Terraform configuration for this deployment,
and it seems as if Terraform does support uploading of public SSH keys
via the
[aws\_key\_pair](https://www.terraform.io/docs/providers/aws/r/key_pair.html)
resource.
Thus I will delete the public SSH key from AWS before continuing:

    $ aws ec2 delete-key-pair --key-name PubCloud2020
    $ aws ec2 describe-key-pairs
    ------------------
    |DescribeKeyPairs|
    +----------------+
    $ aws ec2 describe-key-pairs --output json
    {
          "KeyPairs": []
    }

## 2. Deploy a VM in the default VPC

### Determining the AMI ID

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

I have used many different GNU/Linux distributions in over 25 years
of personal and professional use,
starting with the
[Linux Support Team Erlangen](https://archiveos.org/lst/)
distribution in the first half of the 1990s.
The list includes well known distributions like
[Slackware](http://www.slackware.com/),
[S.u.S.E.](https://www.suse.com/)
(now SUSE),
[Red Hat](https://www.redhat.com/)
(even before there was a *Red Hat Enterpise Linux* product),
[Fedora](https://getfedora.org/)
(both with and without *Core* as part of the name),
[Debian](https://www.debian.org/),
and
[Ubuntu](https://ubuntu.com/).
It includes less well know distributions too, e.g.,
[Deutsche Linux Distribution](https://de.wikipedia.org/wiki/Deutsche_Linux-Distribution)
(DLD, bought by Red Hat), and
[Mandrake](https://en.wikipedia.org/wiki/Mandriva_Linux)
which later became Mandriva and then
[OpenMandriva](https://www.openmandriva.org/).
I have probably forgotten quite a few distributions I used. ;-)
Nowadays I primarily use Debian GNU/Linux for servers and
Ubuntu for notebooks and workstations.

Anyway, I might want to try out
[Amazon Linux 2](https://aws.amazon.com/amazon-linux-2/)
or use
[Ubuntu](https://ubuntu.com/)
for this exercise.

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

## 3. Create a Public S3 Bucket

## 4. Enable Static Web Site Hosting on the S3 Bucket

## 5. Install and Enable a Web Server on the VM

## 6. Add a Static Web Page Referencing the S3 Bucket

## 7. Add the Web Server's IP to the Web Page

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
