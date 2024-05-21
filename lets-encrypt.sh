#!/bin/bash
# this must be run in the Elastic Beanstalk postdeploy hook so that nginx config doesn't get overwritten by Elastic Beanstalk

# ---- Configuration ----
#domain - The domain for which you want to generate the certificate (comma separated for multiple domains) ex: `myapp.acme.com,myapp-staging.acme.com`
#contact - The email address to use for Let's Encrypt
#bucket - The S3 bucket to use for storing the certificates
#test_mode -  Set to `false` to use the Let's Encrypt production server and get a valid certificate. Test certificates are not trusted by browsers, but are useful for testing the deployment.
#environment - The Elastic Beanstalk environment name (test, production, etc.)
#
# Any of these values can also be configured in your EB environment variables rather than specified here. Settings here will override environment variables.

domain="my-app.company.com"
contact="contact@company.com"
bucket="my-ssl-certificates-bucket"
test_mode=true
environment="production"
# -----------------------

# increase server_names_hash_bucket_size to 128 to handle long domain names in nginx
sed -i 's/http {/http {\n    server_names_hash_bucket_size 128;/' /etc/nginx/nginx.conf

#add cron job
function add_cron_job {
    touch /etc/cron.d/certbot_renew
    echo "* * * * * webapp 0 2 * * * certbot renew --allow-subset-of-names
    # empty line" | tee /etc/cron.d/certbot_renew
}

#check if certbot is already installed
if command -v certbot &>/dev/null; then
    echo "certbot already installed"
else
    # Install certbot since it's not installed already
    # Instructions from https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/SSL-on-amazon-linux-2.html#letsencrypt

    sudo dnf install -y python3-certbot-nginx
fi

if [ "$test_mode" = true ]; then
    folder="s3://${bucket}/${environment}/LetsEncrypt-Staging/"
else
    folder="s3://${bucket}/${environment}/LetsEncrypt/"
fi

# check if the S3 bucket already exists with a certificate
if [ -n "$(aws s3 ls $folder)" ]; then

    # download and install certificate from existing S3 bucket
    echo "$folder exists."
    sudo rm -rf /etc/letsencrypt/*
    sudo aws s3 cp ${folder}backup.tar.gz /tmp
    sudo tar -xzvf /tmp/backup.tar.gz --directory /
    sudo chown -R root:root /etc/letsencrypt

    if [ "$test_mode" = true ]; then
        sudo certbot -n -d ${domain} --nginx --agree-tos --email ${contact} --reinstall --redirect --expand --allow-subset-of-names --test-cert
    else
        sudo certbot -n -d ${domain} --nginx --agree-tos --email ${contact} --reinstall --redirect --expand --allow-subset-of-names
    fi
    systemctl reload nginx

    # re-uploading the certificate in case of renewal during certbot installation
    tar -czvf /tmp/backup.tar.gz /etc/letsencrypt/*
    aws s3 cp /tmp/backup.tar.gz ${folder}

    add_cron_job
    exit
fi

# obtain, install, and upload certificate to S3 bucket since it does not exist already
if [ "$test_mode" = true ]; then
    #get a test mode cert
    sudo certbot -n -d ${domain} --nginx --agree-tos --email ${contact} --redirect --allow-subset-of-names --test-cert
else
    #get a production cert
    sudo certbot -n -d ${domain} --nginx --agree-tos --email ${contact} --redirect --allow-subset-of-names
fi

tar -czvf /tmp/backup.tar.gz /etc/letsencrypt/*
aws s3 cp /tmp/backup.tar.gz ${folder}

add_cron_job
