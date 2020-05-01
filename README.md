# Networking in Public Cloud Deployments 2020

This is a repository for my solutions to hands-on assignments (exercises)
of the
[Networking in Public Cloud Deployments](https://www.ipspace.net/PubCloud/)
course during spring of 2020.

This repository fulfills a dual purpose:

1. To submit solutions to the course exercises.
2. As a reference for me (and potentially others).

My solutions may be longer than strictly necessary.
I want to really understand what happens,
and I want to create a reference for me.
This probably takes more time than just hacking togther a solution,
but it results in a better learning experience for me.
Additionally, I take notes while working on the assignments,
instead of creating a report after the fact.
I even keep mistakes in the report,
as long as I think they can be a useful reference.

## Links to the Exercise Solutions

1. [Define the Requirements](ex1-reqs/) - ruminations on cloud use
2. [Simple Infrastructure-as-Code Setup](ex2-iac/) - looking at AWS,
   AWS CloudFormation, and Terraform
3. [Deploy a Cloud-Based Web Server](ex3-web/) - all of SSH, Security Groups,
   EC2, Cloud-Init, S3, and S3 static web site hosting in a single Terraform
   configuration
4. [Deploy a Virtual Network Infrastructure](ex4-infra/) - a VPC, public and
   private subnets, elastic IP address, elastic network interfaces, and
   three EC2 instances

## Additional Stuff

Since I want to use this repository as a reference,
I'll add additional stuff not part of the hands-on exercises as well.

1. [S3 Public Access Block](extra/s3-pab/) - controlling the S3 Public Access
   Block with Terraform
2. [Amazon Linux 2](extra/amazon-linux2/) - playing with Amazon Linux 2, where
   we install Apache and add a second network interface

---

[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
