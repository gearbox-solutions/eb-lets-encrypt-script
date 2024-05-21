# EB Let's Encrypt Script

Let's Encrypt SSL certificates are a great way to secure your website for free, and the automated renewal process is very convenient. However, the process of scripting their deployment and renewal can be challenging for single-instance Elastic Beanstalk deployments. 

Elastic Beanstalk regularly destroys and recreates EC2 instances as part of the instance security maintenance and app deployment processes. This means that the certificates stored on the instance will be lost when the instance is destroyed. If you force-fetch a new cert from LE you run the risk of hitting your certificate limit and being stuck without a valid certificate. This script automates the process of renewing and storing the certificates in S3 for use in Elastic Beanstalk when new instances are deployed.

You should not use this script if you are using a load balancer with SSL termination. In that case, AWS will provide your SSL certificate and manage the renewal process for you.

## Usage

### 1. Add the script to your project
Place the `lets-encrypt.sh` in your project's `/.platform/hooks/postdeploy/` directory. Shell scripts in this location are run as part of the [EB post-deploy hooks](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/platforms-linux-extend.html_. The script needs to be run in post-deploy to make sure Elastic Beanstalk has finished its nginx configuration, otherwise the changes from CertBot may be overwritten. 

You may want to rename the file to give a number for your execution order, as platform hook scripts are executed in alphabetical order. For example, `10_lets-encrypt.sh`.

### 2. Configure the script

Make the following changes to the script to match your environment:

```
domain - The domain for which you want to generate the certificate (comma separated for multiple domains) ex: `myapp.acme.com,myapp-staging.acme.com`
contact - The email address to use for Let's Encrypt
bucket - The S3 bucket to use for storing the certificates
test_mode - Set to `true` to use the Let's Encrypt staging server
environment - The Elastic Beanstalk environment name (test, production, etc.)
```

### 3. Configure your EB EC2 role to allow access to S3

This script stores the certificates in an S3 bucket so that the still-valid certificates can be retrieved and reused. You will need to give your EC2 instance the necessary permissions to write to the S3 bucket by configuring the Elastic Beanstalk EC2 role.

Create a new IAM policy with the following permissions:

> Replace `my-bucket-name` with the actual name of the S3 bucket which will store the certificates.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VisualEditor0",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket-name/*",
        "arn:aws:s3:::my-bucket-name"
      ]
    }
  ]
}
```

After the policy is created, attach it to the Elastic Beanstalk EC2 role. The default role is named `aws-elasticbeanstalk-ec2-role` and can be found in the IAM roles.

## Example script
[Script](/10_certbot-platform-hook.sh.dist) is an example script that downloads and runs this script as part of the .platform hooks in Elastic Beanstalk.

## Staging and production environments
If you interchange your staging and production environments, you should define the staging and production domains the same. This will allow the certificates to be renewed without requiring both domains to pass validation when doing a renew.
