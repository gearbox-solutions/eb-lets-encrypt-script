# EB Let's Encrypt Script

This script is a simple way to generate a certificate for your Elastic Beanstalk environment using Let's Encrypt.

## Usage
You can use this script by defining the following variables and then running the script
```
domain - The domain for which you want to generate the certificate (comma separated for multiple domains)
contact - The email address to use for Let's Encrypt
bucket - The S3 bucket to use for storing the certificates
test_mode - Set to `true` to use the Let's Encrypt staging server
environment - The Elastic Beanstalk environment name (test, production, etc.)
```
Run `./letsencrypt.sh

## Example script
[Script](/10_certbot-platform-hook.sh.dist) is an example script that downloads and runs this script as part of the .platform hooks in Elastic Beanstalk.

## Staging and production environments
If you interchange your staging and production environments, you should define the staging and production domains the same. This will allow the certificates to be renewed without requiring both domains to pass validation when doing a renew.
