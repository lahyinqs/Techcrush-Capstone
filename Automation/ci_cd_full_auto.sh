#!/bin/bash
set -e

echo "🚀 Starting Techcrush CI/CD automation..."

# ================================
# 1️⃣ CONFIGURATION
# ================================
AWS_REGION="us-east-1"
PROJECT_NAME="Techcrush"
VPC_NAME="${PROJECT_NAME}-VPC"
SUBNET_NAME="${PROJECT_NAME}-Subnet"
SG_NAME="${PROJECT_NAME}-Web-SG"
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2 (us-east-1)
INSTANCE_TYPE="t2.micro"
KEY_NAME="${PROJECT_NAME}-Key"
HTML_DIR="/var/www/html"

echo "✅ Configuration loaded for project: $PROJECT_NAME"

# ================================
# 2️⃣ CREATE KEY PAIR
# ================================
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region $AWS_REGION >/dev/null 2>&1; then
  echo "🔑 Creating new key pair..."
  aws ec2 create-key-pair --key-name "$KEY_NAME" \
    --query "KeyMaterial" --output text > "${KEY_NAME}.pem"
  chmod 400 "${KEY_NAME}.pem"
else
  echo "ℹ️ Key pair $KEY_NAME already exists, skipping..."
fi

# ================================
# 3️⃣ CREATE VPC
# ================================
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --region $AWS_REGION \
  --query "Vpc.VpcId" --output text)
echo "✅ VPC created: $VPC_ID"

# Tagging VPC
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="$VPC_NAME"

# ================================
# 4️⃣ CREATE SUBNET
# ================================
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone "${AWS_REGION}a" \
  --query "Subnet.SubnetId" --output text)

aws ec2 create-tags --resources "$SUBNET_ID" --tags Key=Name,Value="$SUBNET_NAME"
echo "✅ Subnet created: $SUBNET_ID"

# ================================
# 🌐 INTERNET GATEWAY & ROUTING
# ================================
IGW_ID=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
echo "✅ Internet Gateway created and attached: $IGW_ID"

# Create route table and route
RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query "RouteTable.RouteTableId" --output text)
aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID"
echo "✅ Route table configured: $RT_ID"


# ================================
# 5️⃣ CREATE SECURITY GROUP
# ================================
SG_ID=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "Allow HTTP and SSH" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" --output text)

echo "✅ Security Group created: $SG_ID"

# Allow SSH + HTTP inbound rules
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# ================================
# 6️⃣ LAUNCH EC2 INSTANCE
# ================================
echo "🖥️ Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --query "Instances[0].InstanceId" \
  --output text)

echo "✅ EC2 instance launched: $INSTANCE_ID"

# Wait for it to start
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "⏳ Instance is now running..."

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)
echo "🌍 Public IP: http://$PUBLIC_IP"

# ================================
# 7️⃣ DEPLOY WEBSITE
# ================================
echo "📦 Deploying website files..."

# Copy all HTML and assets to EC2
scp -o StrictHostKeyChecking=no -i "${KEY_NAME}.pem" -r index.html about.html contact.html techcrush_logo.png ubuntu@"$PUBLIC_IP":/tmp/

# SSH into instance and configure NGINX
ssh -o StrictHostKeyChecking=no -i "${KEY_NAME}.pem" ubuntu@"$PUBLIC_IP" <<EOF
  sudo apt update -y
  sudo apt install nginx -y
  sudo rm -rf $HTML_DIR/*
  sudo mv /tmp/*.html $HTML_DIR/
  sudo mv /tmp/techcrush_logo.png $HTML_DIR/
  sudo systemctl enable nginx
  sudo systemctl restart nginx
EOF

echo "✅ Website deployed successfully!"
echo "🌐 Access it at: http://$PUBLIC_IP"
