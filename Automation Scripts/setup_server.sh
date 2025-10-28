#!/bin/bash
# setup_server.sh — Prepare EC2 web server and deploy Techcrush website

set -e

echo "🚀 Updating server and installing Nginx..."
sudo yum update -y
sudo amazon-linux-extras install nginx1 -y

echo "🧹 Cleaning old site files..."
sudo rm -rf /usr/share/nginx/html/*
sudo mkdir -p /usr/share/nginx/html
sudo chown -R ec2-user:ec2-user /usr/share/nginx/html

echo "📂 Deploying latest website content..."
cp -r * /usr/share/nginx/html/

echo "⚙️ Adjusting Nginx configuration..."
sudo tee /etc/nginx/conf.d/techcrush.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

echo "🔁 Restarting Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "✅ Deployment complete! Website should be live."

