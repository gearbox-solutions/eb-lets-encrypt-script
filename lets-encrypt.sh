#!/bin/bash
# this must be done in postdeploy so that nginx config doesn't get overwritten by Elastic Beanstalk

# ---- Configuration ----
# domain string domains used by certbot (comma separated)
# contact string email address for certbot
# bucket string s3 bucket name
# test_mode boolean true if test mode cert is desired
# environment string environment name
# -----------------------

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
