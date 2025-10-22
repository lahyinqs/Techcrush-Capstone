#!/bin/bash

# automation/4_webserver_setup.sh
# Install NGINX and deploy static website using AWS SSM

# Variables
INSTANCE_ID=$(cat automation/instance_id.txt)
REGION="us-east-1"

# Check if NGINX is installed
NGINX_STATUS=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"systemctl is-active nginx\"]" \
  --region $REGION \
  --query "Command.CommandId" --output text)
STATUS=$(aws ssm get-command-invocation --command-id $NGINX_STATUS --instance-id $INSTANCE_ID --region $REGION --query "StatusDetails" --output text)

if [ "$STATUS" != "Active" ]; then
    echo "Installing NGINX via SSM..."
    aws ssm send-command \
      --instance-ids $INSTANCE_ID \
      --document-name "AWS-RunShellScript" \
      --parameters "commands=[
        \"sudo apt update -y\",
        \"sudo apt install nginx -y\",
        \"sudo systemctl start nginx\",
        \"sudo systemctl enable nginx\"
      ]" \
      --region $REGION \
      --output text
else
    echo "NGINX already installed and running"
fi

# Create and upload HTML file
echo "Creating sample HTML file..."
cat << 'EOF' > automation/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Techcrush Capstone</title>
</head>
<body>
    <h1>Welcome to Techcrush Capstone!</h1>
    <p>This is a static website deployed on AWS EC2 with NGINX.</p>
</body>
</html>
EOF

echo "Uploading HTML file via SSM..."
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    \"sudo mkdir -p /var/www/html\",
    \"sudo mv /home/ubuntu/index.html /var/www/html/index.html\",
    \"sudo chown www-data:www-data /var/www/html/index.html\",
    \"sudo chmod 644 /var/www/html/index.html\"
  ]" \
  --region $REGION \
  --output text

echo "Module 4 completed! Website deployed."