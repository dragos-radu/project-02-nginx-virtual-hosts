# Project 02 – Multiple Static Websites with Nginx Virtual Hosts

## Goal

Deploy two static websites on the same AWS EC2 instance using Nginx virtual hosts, custom subdomains, and HTTPS with a Let's Encrypt wildcard certificate.

## Jira

Epic: DEVOPS-3 – Configure Nginx Virtual Hosts on AWS

Tasks:
- DEVOPS-4: Configure DNS records
- DEVOPS-5: Configure Nginx virtual hosts
- DEVOPS-6: Configure SSL wildcard certificate
- DEVOPS-7: Validate domains and HTTPS

## Status
In Progess

## Planned Domains

- app1.devopsroad.xyz
- app2.devopsroad.xyz

## Tech Stack

- AWS EC2
- Ubuntu
- Nginx
- Route 53 / DNS
- Let's Encrypt

## DEVOPS-4 – DNS and EC2 Preparation

### Objective

Prepare the AWS infrastructure required for hosting multiple static websites with Nginx virtual hosts.

This step creates a new EC2 instance, a dedicated key pair, and a security group that allows SSH, HTTP, and HTTPS traffic.

### Environment Variables

```bash
export AWS_REGION="eu-central-1"
export PROJECT_NAME="project-02-nginx-virtual-hosts"
export KEY_NAME="devopsroad-project02-key"
export INSTANCE_TYPE="t3.micro"
export SECURITY_GROUP_NAME="project-02-nginx-sg"
export INSTANCE_NAME="project-02-nginx-vhosts"
```

### Create EC2 Key Pair

```bash
aws ec2 create-key-pair \
  --region $AWS_REGION \
  --key-name $KEY_NAME \
  --query 'KeyMaterial' \
  --output text > ${KEY_NAME}.pem

chmod 400 ${KEY_NAME}.pem
```

### Get Default VPC ID

```bash
export VPC_ID=$(aws ec2 describe-vpcs \
  --region $AWS_REGION \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text)

echo $VPC_ID
```

### Create Security Group

```bash
export SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --region $AWS_REGION \
  --group-name $SECURITY_GROUP_NAME \
  --description "Security group for Project 02 Nginx virtual hosts" \
  --vpc-id $VPC_ID \
  --query "GroupId" \
  --output text)

echo $SECURITY_GROUP_ID
```

### Allow SSH, HTTP and HTTPS Traffic

```bash
aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --region $AWS_REGION \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### Get Ubuntu 22.04 AMI ID

```bash
export AMI_ID=$(aws ec2 describe-images \
  --region $AWS_REGION \
  --owners 099720109477 \
  --filters \
    "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text)

echo $AMI_ID
```

### Create EC2 Instance

```bash
export INSTANCE_ID=$(aws ec2 run-instances \
  --region $AWS_REGION \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SECURITY_GROUP_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=$PROJECT_NAME}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo $INSTANCE_ID
```

### Wait for Instance to Start

```bash
aws ec2 wait instance-running \
  --region $AWS_REGION \
  --instance-ids $INSTANCE_ID
```

### Get EC2 Public IP

```bash
export EC2_PUBLIC_IP=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo $EC2_PUBLIC_IP
```

### Connect to EC2

```bash
ssh -i ${KEY_NAME}.pem ubuntu@$EC2_PUBLIC_IP
```

### Created AWS Resources

```text
Region: eu-central-1
Instance type: t3.micro
Instance name: project-02-nginx-vhosts
Security group: project-02-nginx-sg
Allowed inbound ports: 22, 80, 443
```

### DNS Records to Create

```text
Type    Name    Value
A       app1    EC2_PUBLIC_IP
A       app2    EC2_PUBLIC_IP
```

### Notes

The EC2 instance public IP will be used later for the DNS A records.

The private key file must not be committed to GitHub:

```text
devopsroad-project02-key.pem
```

Sensitive data such as private keys, AWS access keys, AWS secret keys, and passwords must never be stored in this repository.

### DNS Records Created

The following DNS A records were created in AWS Route 53:

```text
Type    Name                    Value
A       app1.devopsroad.xyz     EC2_PUBLIC_IP
A       app2.devopsroad.xyz     EC2_PUBLIC_IP
```

Both records point to the same EC2 instance public IP address.

### DNS Validation

The following commands were used to validate DNS resolution:

```bash
dig app1.devopsroad.xyz +short
dig app2.devopsroad.xyz +short
```

Both subdomains resolved successfully to the EC2 public IP address.

### DNS Delegation

The domain `devopsroad.xyz` was registered using Namecheap.

DNS management was delegated to AWS Route 53 by configuring the Route 53 nameservers as custom DNS nameservers in Namecheap.

Final DNS flow:

```text
Namecheap domain registration
        |
        | custom nameservers
        v
AWS Route 53 Hosted Zone
        |
        | A records
        v
EC2 public IP
```

## DEVOPS-5 – Configure Nginx Virtual Hosts

### Objective

Configure Nginx to serve two different static websites from the same AWS EC2 instance using virtual hosts.

Each website is stored in the GitHub repository and deployed to the EC2 instance using the `setup.sh` deployment script.

### Repository-based Deployment Flow

```text
GitHub repository
        |
        | git clone / git pull
        v
EC2 Ubuntu Server
        |
        | setup.sh
        v
Nginx virtual hosts
        |
        ├── app1.devopsroad.xyz -> /var/www/app1
        └── app2.devopsroad.xyz -> /var/www/app2
```

### Website Source Files

The static websites are stored in the repository:

```text
sites/
├── app1/
│   └── index.html
└── app2/
    └── index.html
```

### Nginx Configuration Files

The Nginx virtual host configuration files are stored in the repository:

```text
nginx/
├── app1.conf
└── app2.conf
```

### App1 Virtual Host

```nginx
server {
    listen 80;
    server_name app1.devopsroad.xyz;

    root /var/www/app1;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### App2 Virtual Host

```nginx
server {
    listen 80;
    server_name app2.devopsroad.xyz;

    root /var/www/app2;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Deployment Script

The deployment is automated using:

```bash
./setup.sh
```

The script performs the following actions:

```text
1. Installs Nginx
2. Creates /var/www/app1 and /var/www/app2
3. Copies static website files from the repository to /var/www
4. Copies Nginx virtual host configs to /etc/nginx/sites-available
5. Enables both virtual hosts using symbolic links
6. Disables the default Nginx site
7. Tests the Nginx configuration
8. Reloads Nginx
```

### Deployment on EC2

The repository was cloned on the EC2 instance:

```bash
git clone https://github.com/USERNAME/project-02-nginx-virtual-hosts.git
cd project-02-nginx-virtual-hosts
```

For branch-based validation before merging the pull request, the following branch was used:

```bash
git checkout DEVOPS-5-configure-nginx-virtual-hosts
```

The setup script was executed:

```bash
chmod +x setup.sh
./setup.sh
```

### Nginx Validation

The Nginx configuration was validated using:

```bash
sudo nginx -t
```

Expected result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### Local EC2 Validation

The virtual hosts were tested locally on the EC2 instance using the `Host` header:

```bash
curl -H "Host: app1.devopsroad.xyz" http://localhost
curl -H "Host: app2.devopsroad.xyz" http://localhost
```

Expected result:

```text
App1 running on Nginx
App2 running on Nginx
```

### Public HTTP Validation

The websites were validated in the browser using:

```text
http://app1.devopsroad.xyz
http://app2.devopsroad.xyz
```

Both subdomains successfully served different static websites from the same EC2 instance using Nginx virtual hosts.

### Notes

At this stage, the websites are available over HTTP only.

HTTPS and wildcard SSL configuration will be handled in the next task:

```text
DEVOPS-6: Configure SSL wildcard certificate
```

## DEVOPS-6 – Configure SSL Wildcard Certificate

### Objective

Configure HTTPS for both Nginx virtual hosts using a Let's Encrypt wildcard certificate.

The certificate covers:

```text
*.devopsroad.xyz
devopsroad.xyz
```

This allows both subdomains to use the same SSL certificate:

```text
https://app1.devopsroad.xyz
https://app2.devopsroad.xyz
```

### SSL Architecture

```text
Browser
   |
   | HTTPS
   v
Nginx on EC2
   |
   | wildcard certificate
   v
Let's Encrypt certificate for *.devopsroad.xyz
```

### DNS Challenge Method

The wildcard certificate was generated using a DNS challenge.

Because DNS is managed in AWS Route 53, Certbot was configured with the Route 53 DNS plugin:

```bash
sudo apt install certbot python3-certbot-dns-route53 -y
```

### IAM Role for Certbot

An IAM role was attached to the EC2 instance to allow Certbot to create and remove temporary DNS challenge records in Route 53.

IAM policy used:

```text
Project02CertbotRoute53Policy
```

IAM role used:

```text
Project02CertbotRoute53Role
```

The role allows Certbot to access Route 53 without storing AWS access keys directly on the server.

### Required Route 53 Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetChange"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    }
  ]
}
```

### Verify IAM Role on EC2

The IAM role was validated from the EC2 instance using:

```bash
aws sts get-caller-identity
```

Expected result:

```text
arn:aws:sts::<account-id>:assumed-role/Project02CertbotRoute53Role/...
```

### Certbot Dry Run

Before requesting the real certificate, a dry run was executed:

```bash
sudo certbot certonly \
  --dns-route53 \
  -d "*.devopsroad.xyz" \
  -d "devopsroad.xyz" \
  --dry-run \
  --agree-tos \
  -m an-email@example.com \
  --non-interactive
```

### Generate Wildcard Certificate

The real wildcard certificate was generated using:

```bash
sudo certbot certonly \
  --dns-route53 \
  -d "*.devopsroad.xyz" \
  -d "devopsroad.xyz" \
  --agree-tos \
  -m an-email@example.com \
  --non-interactive
```

### Certificate Location

The certificate files were generated under:

```text
/etc/letsencrypt/live/devopsroad.xyz/
```

Main files used by Nginx:

```text
/etc/letsencrypt/live/devopsroad.xyz/fullchain.pem
/etc/letsencrypt/live/devopsroad.xyz/privkey.pem
```

### Nginx HTTPS Configuration

Both Nginx virtual hosts were updated to listen on port 443 and use the wildcard certificate.

HTTP traffic is redirected to HTTPS.

Example:

```nginx
server {
    listen 80;
    server_name app1.devopsroad.xyz;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name app1.devopsroad.xyz;

    ssl_certificate /etc/letsencrypt/live/devopsroad.xyz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/devopsroad.xyz/privkey.pem;

    root /var/www/app1;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Nginx Validation

The Nginx configuration was validated using:

```bash
sudo nginx -t
```

Expected result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Nginx was reloaded using:

```bash
sudo systemctl reload nginx
```

### HTTPS Validation

The HTTPS endpoints were tested using:

```bash
curl -I https://app1.devopsroad.xyz
curl -I https://app2.devopsroad.xyz
```

Expected result:

```text
HTTP/1.1 200 OK
```

or:

```text
HTTP/2 200
```

### HTTP to HTTPS Redirect Validation

The HTTP endpoints were tested using:

```bash
curl -I http://app1.devopsroad.xyz
curl -I http://app2.devopsroad.xyz
```

Expected result:

```text
HTTP/1.1 301 Moved Permanently
Location: https://app1.devopsroad.xyz/
```

and:

```text
HTTP/1.1 301 Moved Permanently
Location: https://app2.devopsroad.xyz/
```

### Browser Validation

Both websites were successfully validated in Google Chrome:

```text
https://app1.devopsroad.xyz
https://app2.devopsroad.xyz
```

Both domains display the correct static website content over HTTPS.

## DEVOPS-7 – Validate Domains and HTTPS

### Objective

Validate the final setup for both static websites.

This task confirms that DNS, Nginx virtual hosts, HTTPS, HTTP-to-HTTPS redirects, and logging are working correctly.

### Validation Scope

The validation covers:

```text
DNS resolution
HTTP to HTTPS redirect
HTTPS availability
SSL certificate details
Nginx configuration
Nginx service status
Website content
Nginx access and error logs
Browser validation
```

### DNS Validation

The following commands were used to verify that both subdomains resolve to the EC2 public IP address:

```bash
dig app1.devopsroad.xyz +short
dig app2.devopsroad.xyz +short
```

Expected result:

```text
Both domains return the EC2 public IP address.
```

### HTTP to HTTPS Redirect Validation

The HTTP endpoints were tested using:

```bash
curl -I http://app1.devopsroad.xyz
curl -I http://app2.devopsroad.xyz
```

Expected result:

```text
HTTP/1.1 301 Moved Permanently
Location: https://app1.devopsroad.xyz/

HTTP/1.1 301 Moved Permanently
Location: https://app2.devopsroad.xyz/
```

This confirms that all HTTP traffic is redirected to HTTPS.

### HTTPS Validation

The HTTPS endpoints were tested using:

```bash
curl -I https://app1.devopsroad.xyz
curl -I https://app2.devopsroad.xyz
```

Expected result:

```text
HTTP/2 200
```

or:

```text
HTTP/1.1 200 OK
```

This confirms that both websites are available over HTTPS.

### Website Content Validation

The website content was validated using:

```bash
curl -s https://app1.devopsroad.xyz | grep "App1 running on Nginx"
curl -s https://app2.devopsroad.xyz | grep "App2 running on Nginx"
```

Expected result:

```text
App1 running on Nginx
App2 running on Nginx
```

This confirms that each subdomain serves the correct static website.

### SSL Certificate Validation

The SSL certificate was inspected using:

```bash
openssl s_client -connect app1.devopsroad.xyz:443 -servername app1.devopsroad.xyz </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

```bash
openssl s_client -connect app2.devopsroad.xyz:443 -servername app2.devopsroad.xyz </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

Expected result:

```text
The certificate is issued by Let's Encrypt and is valid for the configured domain.
```

### Nginx Configuration Validation

On the EC2 instance, the Nginx configuration was validated using:

```bash
sudo nginx -t
```

Expected result:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### Nginx Service Validation

The Nginx service status was checked using:

```bash
systemctl status nginx
```

Expected result:

```text
active (running)
```

### Nginx Logs Validation

Access logs were checked using:

```bash
sudo tail -n 30 /var/log/nginx/access.log
```

Error logs were checked using:

```bash
sudo tail -n 30 /var/log/nginx/error.log
```

Expected result:

```text
Requests are visible in the access log and no critical errors are present in the error log.
```

### Browser Validation

Both websites were validated in Google Chrome:

```text
https://app1.devopsroad.xyz
https://app2.devopsroad.xyz
```

Expected result:

```text
Both websites load successfully over HTTPS and display the correct static content.
```

### Screenshots

Validation screenshots are stored in:

```text
screenshots/
```

Recommended screenshots:

```text
screenshots/app1.png
screenshots/app2.png
screenshots/https-validation.png
screenshots/nginx-validation.png
```

### Final Result

The final architecture is working successfully:

```text
Internet
   |
   v
Route 53 DNS
   |
   v
AWS EC2 Ubuntu Server
   |
   v
Nginx Virtual Hosts
   |
   ├── app1.devopsroad.xyz -> /var/www/app1 -> HTTPS
   └── app2.devopsroad.xyz -> /var/www/app2 -> HTTPS
```

Project 02 successfully demonstrates a production-like Nginx virtual host setup with custom subdomains and HTTPS using a Let's Encrypt wildcard certificate.