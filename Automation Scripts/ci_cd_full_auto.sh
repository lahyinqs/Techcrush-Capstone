#!/bin/bash

echo "🚀 Starting Techcrush CI/CD Automation..."

# === CONFIGURATION ===
KEY_PATH="/home/devopninja/techcrush-key.pem"
KEY_NAME="techcrush-key"
REGION="us-east-1"
AMI_ID="ami-0c398cb65a93047f2"  # Ubuntu 22.04 LTS
INSTANCE_TYPE="t2.micro"
PROJECT_TAG="Techcrush"
WEB_FILES_PATH="/mnt/c/Users/Harrylite/DevOpsNinja/Techcrush-Capstone"  # Local repo path containing HTML files

# === CHECKS ===
if [ ! -f "$KEY_PATH" ]; then
  echo "❌ ERROR: Cannot find PEM key at $KEY_PATH"
  exit 1
fi

if [ ! -d "$WEB_FILES_PATH" ]; then
  echo "❌ ERROR: Local repo folder not found at $WEB_FILES_PATH"
  exit 1
fi

echo "✅ Found PEM key and web files folder."

# === CREATE NETWORKING ===
echo "🌐 Setting up VPC, Subnet, IGW, and Route Table..."

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text --region $REGION)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}" --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION
echo "✅ VPC created: $VPC_ID"

SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --query 'Subnet.SubnetId' --output text --region $REGION)
echo "✅ Subnet created: $SUBNET_ID"

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region $REGION)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
echo "✅ Internet Gateway created and attached: $IGW_ID"

RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text --region $REGION)
aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RTB_ID --region $REGION
echo "✅ Route table configured: $RTB_ID"

# === SECURITY GROUP ===
echo "🛡️ Creating Security Group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name "techcrush-sg" \
  --description "Allow HTTP and SSH" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text --region $REGION)

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
echo "✅ Security Group created: $SG_ID"

# === EC2 INSTANCE ===
echo "🖥️ Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PROJECT_TAG}]" \
  --query 'Instances[0].InstanceId' --output text --region $REGION)

echo "⏳ Waiting for instance to initialize..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)

echo "✅ EC2 running at: $PUBLIC_IP"

# === INSTALL APACHE AND DEPLOY WEBSITE ===
echo "🌍 Installing Apache and deploying site to EC2..."

ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@$PUBLIC_IP <<EOF
  sudo apt update -y
  sudo apt install apache2 -y
  sudo systemctl enable apache2
  sudo systemctl start apache2
  sudo rm -rf /var/www/html/*
EOF

# === COPY WEB FILES FROM LOCAL REPO ===
scp -i "$KEY_PATH" $WEB_FILES_PATH/*.html ubuntu@$PUBLIC_IP:/var/www/html/

# === FINAL PERMISSIONS ===
ssh -i "$KEY_PATH" ubuntu@$PUBLIC_IP <<EOF
  sudo chown -R www-data:www-data /var/www/html
  sudo chmod -R 755 /var/www/html
EOF

echo "✅ Website deployed successfully!"

# === OUTPUT DEPLOYMENT DETAILS ===
echo "🌐 Visit your site at: http://$PUBLIC_IP"
echo "🎉 Deployment complete for project: $PROJECT_TAG"
