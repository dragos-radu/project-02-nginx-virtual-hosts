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