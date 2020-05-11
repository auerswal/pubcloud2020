# Exercise 6: Secure Your Virtuel Network Infrastructure

This exercise continues with the virtual betwork infrastructure from the
two preceding hands-on exercises.
Here we are to add security to the existing deployment.
While this makes sense from a teaching perspective,
a production deployment *must* include security from the beginning,
or it will be insecure.

## Overview

This hands-on exercise is comprised of four topics
that each comprise several requirements.
Two of the topics and some of the requirements are optional:

1. Traffic Filters
2. Identity and Access Management
3. Application Firewall (*optional*)
4. Session Logging (*optional*)

### Traffic Filters

We have already implemented traffic filters,
i.e., Security Groups for AWS,
in the previous hands-on exercises.
Now we shall adjust these to be a bit more restrictive than before:

1. Anyone can connect to the web server over HTTP and HTTPS.
2. Specified IP addresses can connect to the SSH jump host over SSH.
3. SSH jump host can connect to any VM within the virtual network over SSH.
4. Web server(s) can connect to database server(s) over HTTP and MySQL
   (or any other similar service).
5. Database server(s) can communicate over HTTP and MySQL.

### Identity and Access Management

We need to create multiple users within our account (or subscription):

1. A user that has read-only access. When using those credentials you should be
   able to see the networking and compute resources, but not modify them.
2. A user that can modify the storage bucket you created in the third exercise,
   but not anything else (*optional*).
3. A user that can view networking resources and modify compute resources.
   Split the deployment procedure into two parts, and deploy networking and
   compute resources using two separate users (*optional*).

### Application Firewall (*optional*)

Add a web application firewall (WAF) in front of your web server
and block any attempts to access `/admin` or `/login` URLs.

### Session Logging (*optional*)

Log all sessions to and from the SSH jump host.

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
