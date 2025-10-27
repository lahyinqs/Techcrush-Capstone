#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

echo "🚀 Starting Techcrush CI/CD Automation..."

# ===============================
# 🧩 CONFIGURATION
# ===============================
AWS_REGION="us-east-1"
AMI_ID="ami-0c398cb65a93047f2"   # Ubuntu 22.04 LTS (Stable in us-east-1)
INSTANCE_TYPE="t2.micro"
KEY_NAME="techcrush-key"
LOCAL_KEY_PATH="/c/Techcrush/techcrush-key.pem"
TAG_PROJECT="Techcrush"
WEB_PORT=80
SSH_PORT=22

# ===============================
# 🔐 CHECK & VALIDATE PEM KEY
# ===============================
if [ ! -f "$LOCAL_KEY_PATH" ]; then
  echo "❌ ERROR: Cannot find PEM key at $LOCAL_KEY_PATH"
  echo "➡️ Please confirm the full path to techcrush-key.pem."
  exit 1
else
  echo "✅ Found PEM key at $LOCAL_KEY_PATH"
fi

# ===============================
# 🌐 NETWORK SETUP (VPC, SUBNET, IGW, ROUTE)
# ===============================
echo "🌐 Setting up VPC, Subnet, IGW, and Route Table..."

VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' \
  --output text \
  --region "$AWS_REGION")
echo "✅ VPC created: $VPC_ID"

SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone "${AWS_REGION}a" \
  --query 'Subnet.SubnetId' \
  --output text)
echo "✅ Subnet created: $SUBNET_ID"

IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
echo "✅ Internet Gateway created and attached: $IGW_ID"

RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$SUBNET_ID" > /dev/null
echo "✅ Route table configured: $RTB_ID"

# ===============================
# 🛡️ SECURITY GROUP
# ===============================
echo "🛡️ Creating Security Group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name "${TAG_PROJECT}-SG" \
  --description "Allow SSH and HTTP" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port "$SSH_PORT" --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port "$WEB_PORT" --cidr 0.0.0.0/0
echo "✅ Security Group created: $SG_ID"

# ===============================
# 💻 EC2 INSTANCE LAUNCH
# ===============================
echo "🚀 Launching EC2 instance with Ubuntu 22.04 AMI ($AMI_ID)..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_PROJECT-Instance}]" \
  --region "$AWS_REGION" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ EC2 instance launched: $INSTANCE_ID"

# ===============================
# 🕐 WAIT FOR INSTANCE
# ===============================
echo "⏳ Waiting for instance to reach 'running' state..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
echo "✅ Instance is running!"

# ===============================
# 🌍 FETCH PUBLIC IP
# ===============================
echo "🔍 Fetching Public IP..."
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

if [[ "$PUBLIC_IP" == "None" || -z "$PUBLIC_IP" ]]; then
  echo "❌ ERROR: Failed to fetch Public IP. Check AWS Console."
  exit 1
else
  echo "🌍 Public IP: http://$PUBLIC_IP"
fi

# ===============================
# ⚙️ SERVER SETUP
# ===============================
echo "🧱 Configuring server via SSH..."
sleep 30  # give SSH daemon time to initialize

ssh -o StrictHostKeyChecking=no -i "$LOCAL_KEY_PATH" ubuntu@"$PUBLIC_IP" <<'EOF'
sudo apt update -y
sudo apt install apache2 -y
sudo systemctl enable apache2
sudo systemctl start apache2
EOF
echo "✅ Apache Web Server installed successfully."

# ===============================
# 📦 DEPLOY WEBSITE FILES
# ===============================
echo "📦 Deploying website files..."
scp -i "$LOCAL_KEY_PATH" -o StrictHostKeyChecking=no \
  index.html Aboutus.html Contact-us.html ubuntu@"$PUBLIC_IP":/tmp/

ssh -i "$LOCAL_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" <<'EOF'
sudo mv /tmp/*.html /var/www/html/
sudo systemctl restart apache2
EOF
echo "✅ Website deployed successfully."

# ===============================
# ✅ FINAL STATUS
# ===============================
echo "🎉 Deployment completed successfully!"
echo "🌐 Visit your website: http://$PUBLIC_IP"
