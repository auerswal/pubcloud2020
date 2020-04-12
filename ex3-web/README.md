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

## 1. Create an SSH Key Pair

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
