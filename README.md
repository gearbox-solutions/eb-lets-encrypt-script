# AWS Elastic Beanstalk Let's Encrypt SSL Certificates

Let's Encrypt SSL certificates are a great way to secure your website for free, and the automated renewal process is very convenient. However, the process of scripting their deployment and renewal can be challenging for single-instance Elastic Beanstalk deployments. 

Elastic Beanstalk regularly destroys and recreates EC2 instances as part of the instance security maintenance and app deployment processes. This means that the certificates stored on the instance will be lost when the instance is destroyed. If you force-fetch a new cert from LE you run the risk of hitting your certificate limit and being stuck without a valid certificate. This script automates the process of renewing and storing the certificates in S3 for use in Elastic Beanstalk when new instances are deployed.

You should not use this script if you are using a load balancer with SSL termination. In that case, AWS will provide your SSL certificate and manage the renewal process for you.

## Usage

### 1. Add the script to your project
Place the `lets-encrypt.sh` in your project's `/.platform/hooks/postdeploy/` directory. Shell scripts in this location are run as part of the [EB post-deploy hooks](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/platforms-linux-extend.html). The script needs to be run in post-deploy to make sure Elastic Beanstalk has finished its nginx configuration, otherwise the changes from CertBot may be overwritten. 

You may want to rename the file to give a number for your execution order, as platform hook scripts are executed in alphabetical order. For example, `10_lets-encrypt.sh`.

### 2. Configure the script

You will need to update the configuration in the script to retrieve the correct certificate. We recommend leaving the script it test mode for initial testing to make sure everything deploys properly without running the risk of hitting the (Let's Encrypt rate limit)[https://letsencrypt.org/docs/rate-limits/]. Leaving test mode enabled will instead fetch test certificates from the (Let's Encrypt staging environment)[https://letsencrypt.org/docs/staging-environment/].

Make the following changes to the script to match your domain and environment settings:


* **domain** - The domain for which you want to generate the certificate (comma separated for multiple domains) ex: `myapp.acme.com,myapp-staging.acme.com`
 
* **contact** - The email address to use for Let's Encrypt
 
* **bucket** - The S3 bucket to use for storing the certificates
 
* **test_mode** -  Set to `false` to use the Let's Encrypt production server and get a valid certificate. Test certificates are not trusted by browsers, but are useful for testing the deployment.
* **environment** - The Elastic Beanstalk environment name (test, production, etc.)

Any of these values can also be configured in your EB environment variables rather than specified in the script. Settings in the script will override environment variables.


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

### 4. Deploy your application

Deploy the new version of your application to Elastic Beanstalk. The script will run as part of the [post-deploy hook](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/platforms-linux-extend.html) and will generate a new certificate if necessary.

Be sure that the `/.platform` folder is included in your build artifact/zip. It may be a hidden file in your OS, so you may need to include it explicitly in your build script. If you're using CodeBuild you should make sure it's included in your artifacts of your `buildspec.yml` file.

## Staging and production environments
If you interchange your staging and production environments (such as for blue-green deployments), you should define the staging and production domains with both values, eg: `app-staging.mycompany.com,app.mycompany.com`. This will allow the certificates to be renewed without requiring both domains to pass validation when doing a renew.
