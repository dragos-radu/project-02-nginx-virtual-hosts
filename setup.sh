#!/bin/bash

set -e

echo "Installing Nginx..."
sudo apt update
sudo apt install nginx -y

echo "Creating website directories..."
sudo mkdir -p /var/www/app1
sudo mkdir -p /var/www/app2

echo "Deploying static websites..."
sudo cp -r sites/app1/* /var/www/app1/
sudo cp -r sites/app2/* /var/www/app2/

echo "Deploying Nginx virtual host configurations..."
sudo cp nginx/app1.conf /etc/nginx/sites-available/app1
sudo cp nginx/app2.conf /etc/nginx/sites-available/app2

echo "Enabling virtual hosts..."
sudo ln -sf /etc/nginx/sites-available/app1 /etc/nginx/sites-enabled/app1
sudo ln -sf /etc/nginx/sites-available/app2 /etc/nginx/sites-enabled/app2

echo "Disabling default Nginx site..."
sudo rm -f /etc/nginx/sites-enabled/default

echo "Testing Nginx configuration..."
sudo nginx -t

echo "Reloading Nginx..."
sudo systemctl enable nginx
sudo systemctl reload nginx

echo "Deployment completed successfully."
