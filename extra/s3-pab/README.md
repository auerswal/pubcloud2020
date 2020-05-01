# Extra: S3 Public Access Block Control

As found out on
[hands-on exercise 3](../../ex3-web/),
the AWS CLI included in Ubuntu 18.04 LTS cannot control the
*S3 Public Access Block*.
Terraform *can*,
but *destroyng* the respective resource
does *not* re-instate the previous settings.
Thus I want to write a Terraform configuration
that allows to easily control just this account wide setting.
Instead of Terraform's *insecure by default*,
I use a *secure by default* approach,
i.e., *applying* the Terraform configuration
[s3\_pab.tf](s3_pab.tf)
in this directory without specifying any variables activates all blocks.

Let's see how this works.
I have applied and destroyed the web server configuration
from hands-on exercise 3,
and see in the AWS Console that the
[S3 Public Access Block](https://s3.console.aws.amazon.com/s3/settings?region=eu-central-1)
has been disabled completely.

First I initialize Terraform using `terraform init`:

```
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
```

I then *apply* the Terraform configuration:

```
$ terraform apply

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_s3_account_public_access_block.s3_pab will be created
  + resource "aws_s3_account_public_access_block" "s3_pab" {
      + account_id              = (known after apply)
      + block_public_acls       = true
      + block_public_policy     = true
      + id                      = (known after apply)
      + ignore_public_acls      = true
      + restrict_public_buckets = true
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_s3_account_public_access_block.s3_pab: Creating...
aws_s3_account_public_access_block.s3_pab: Creation complete after 1s [id=143440624024]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

I can verify via AWS Console that the S3 Public Access Block is now active.
Next I try to disable it using the variable file
[disable\_completely.tfvars](disable_completely.tfvars):

```
$ terraform apply --var-file disable_completely.tfvars
aws_s3_account_public_access_block.s3_pab: Refreshing state... [id=143440624024]

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_s3_account_public_access_block.s3_pab will be updated in-place
  ~ resource "aws_s3_account_public_access_block" "s3_pab" {
        account_id              = "143440624024"
      ~ block_public_acls       = true -> false
      ~ block_public_policy     = true -> false
        id                      = "143440624024"
      ~ ignore_public_acls      = true -> false
      ~ restrict_public_buckets = true -> false
    }

Plan: 0 to add, 1 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_s3_account_public_access_block.s3_pab: Modifying... [id=143440624024]
aws_s3_account_public_access_block.s3_pab: Modifications complete after 1s [id=143440624024]

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

The AWS Console no shows that all of the S3 Public Access Block is disabled.

Now I change the settings via AWS Console,
because I want to try out to read the current state with `terraform refresh`:

```
$ terraform refresh
aws_s3_account_public_access_block.s3_pab: Refreshing state... [id=143440624024]
```

Now the updated (*refreshed*) state can be displayed using `terraform show`:

```
$ terraform show
# aws_s3_account_public_access_block.s3_pab:
resource "aws_s3_account_public_access_block" "s3_pab" {
    account_id              = "143440624024"
    block_public_acls       = true
    block_public_policy     = true
    id                      = "143440624024"
    ignore_public_acls      = false
    restrict_public_buckets = false
}
```

Since I want to re-activate all of the S3 Public Access Block,
I apply the Terraform configuration without variables again:

```
$ terraform apply
aws_s3_account_public_access_block.s3_pab: Refreshing state... [id=143440624024]

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_s3_account_public_access_block.s3_pab will be updated in-place
  ~ resource "aws_s3_account_public_access_block" "s3_pab" {
        account_id              = "143440624024"
        block_public_acls       = true
        block_public_policy     = true
        id                      = "143440624024"
      ~ ignore_public_acls      = false -> true
      ~ restrict_public_buckets = false -> true
    }

Plan: 0 to add, 1 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_s3_account_public_access_block.s3_pab: Modifying... [id=143440624024]
aws_s3_account_public_access_block.s3_pab: Modifications complete after 2s [id=143440624024]

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

---

[PubCloud2020 GitHub repository](https://github.com/auerswal/pubcloud2020) |
[My GitHub user page](https://github.com/auerswal) |
[My home page](https://www.unix-ag.uni-kl.de/~auerswal/)
