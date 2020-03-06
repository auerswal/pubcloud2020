# Exercise 1: Define the Requirements

The first exercise is about defining requirements for a cloud deployment.
While it is suggested to use a real project,
I do not have this possibility.
I will instead use a fictitious project inspired by real opportunities
aligned with the course objectives.

## Cloud Provider for Exercises

I intend to use
[Amazon web Services](https://aws.amazon.com/)
(AWS) for the course exercises as well as for cloud service examples.
The course allows to use any cloud providers that allow implementing
solutions to the exercises.
AWS, Azure, and Google Cloud are given as examples that can be used.
I have not yet used any cloud,
but at first glance AWS seems to me to be both most popular and versatile,
thus I will look into AWS.

## The Project

The fictitious project is based on replacing use of a server from a
dedicated hosting service by using cloud services.
This more or less aligns with the *web site* sample project for this
exercise.

### Reality

> This dramatization is inspired by true events.  However, certain scenes,
> characters, names, businesses, incidents, locations, and events have been
> fictionalized for dramatic purposes.

The real project aligns quite well with the
[AWS Architecture Blog](https://aws.amazon.com/blogs/architecture/)
post
[Architecting a Low-Cost Web Content Publishing System](https://aws.amazon.com/de/blogs/architecture/architecting-a-low-cost-web-content-publishing-system/)
that is given as a simple case study in the first course section.
It is actually a bit simpler and would not require any
[EC2](https://aws.amazon.com/ec2/)
instance,
since the single content management system used can directly write to
[S3](https://aws.amazon.com/s3/).

The dedicated server provides DNS services in addition to a web site.
A good way to move this to the cloud would be to use a DNS SaaS
offering, e.g.,
[Amazon Route 53](http://aws.amazon.com/route53/).

A possible use for an EC2 instance would be hosting the content management
system in the cloud,
but starting the instance only when needed instead of always running it.
The content could be stored using a DBaaS offering,
allowing to create an EC2 instance on-demand from a pre-built image.
The equivalent of a Chromebook might then suffice for content creators.

Anyway, I do not intend to look into the fine details of the above
and instead focus on learning the course content.
The course content relies on several virtual machines
(e.g., EC2 instances)
using different virtual networks
(e.g., [VPC](https://aws.amazon.com/vpc/))
with differing connectivity requirements.

### Fiction

Thus I am using a fictitious public cloud solution oriented on the
*web site* sample project suggestion.
A similar setup *could* be used for the real project,
but it seems to me to miss out on the potential benefits provided
by consequent use of cloud offerings,
and thus *should not* be used.

## Requirements

The exercise contains a list of questions.
Answers to those describe the requirements for the public cloud deployment.

### What services should the public cloud deployment offer to the customers?

* The public cloud deployment should offer a public web site.
* The content of the web site is static in nature,
  but needs to be updated regularly.
* The public web site content should be easy to manage for non-technical staff.

### How will the users consume those services?

#### Will they use Internet access or will you have to provide a more dedicated connectivity solution?

* Users will access the web site via the Internet.
* Users shall be able to use either IPv4 or IPv6.

### Identify the data needed by the solution you're deploying.

#### What data is shared with other applications? Where will the data reside?

* All the data is dedicated to the web site.
* The web site content storage should provide
  [ACID](https://en.wikipedia.org/wiki/ACID)
  properties.
* No other systems need to be queried.

### What are the security requirements of your application?

* Only authorized personnel may change the web content.
* Some resiliency against (distributed) denial of service attacks would be
  nice to have,
  but web site availability is not directly vital for the company.
* Software needs to be kept current (*patched*).

### What are the high availability requirements?

* The web site does not need to be highly available.
* The web site data needs to be backed up to a separate system.

### Do you have to provide connectivity to your on-premises data center?

* No connectivity to the on-premises data center is needed.

#### If so, how will you implement it?

*not applicable*

### Do you have to implement connectivity to other (customer) sites?

* Connectivity is needed from office locations to manage web site content.
* No dedicated connectivity to customer sites is needed.

#### If so, how will you implement it?

Connectivity will use Internet access from the office locations.
The office locations use static public IPv4 and IPv6 addresses that can be
used in security controls.
Web content is updated via HTTPS.

## Reality Check

While the above requirements seem correct at the time of writing,
they may well change over time.
The experience of implementing a solution may result in requirement changes
as well.

As an example it may become helpful to provide some kind of VPN access,
but this is not obvious at the moment.
As another example the importance of the web site might change,
resulting in needs for higher availability and resilience.

There may even come to light that features deemed superfluous at first
are so simple and cheap to use that the benefits outweigh the costs.

I do not know this yet since I am at the start of this journey. ☺

Anyway, whenever some existing requirement changes,
or a new requirement emerges,
There is a real risk to overlook existing requirements
when searching for a solution for an unexpected problem resulting in new
requirements.
It is necessary to verify that the adjusted solution still fulfills the
pre-exisitng and still valid requirements.

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
