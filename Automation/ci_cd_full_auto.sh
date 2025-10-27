#!/bin/bash
set -e

echo "🚀 Starting Techcrush CI/CD Automation..."

# === CONFIGURATION ===
AWS_REGION="us-east-1"
KEY_NAME="techcrush-key"
LOCAL_KEY_PATH="/home/devopninja/techcrush-key.pem"
AMI_ID="ami-0c398cb65a93047f2"
INSTANCE_TYPE="t2.micro"
PROJECT_NAME="Techcrush"
TAG="Techcrush-Auto"

# === CHECK PEM KEY ===
if [ ! -f "$LOCAL_KEY_PATH" ]; then
    echo "❌ ERROR: Cannot find PEM key at $LOCAL_KEY_PATH"
    echo "➡️ Please confirm the full path to $KEY_NAME.pem."
    exit 1
else
    echo "✅ Found PEM key at $LOCAL_KEY_PATH"
fi

# === FIX PERMISSIONS (auto) ===
echo "🔒 Checking and fixing PEM file permissions..."
chmod 400 "$LOCAL_KEY_PATH"
echo "✅ Permissions fixed for PEM file"

# === CREATE NETWORKING COMPONENTS ===
echo "🌐 Setting up VPC, Subnet, IGW, and Route Table..."

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
    --query "Vpc.VpcId" --output text --region "$AWS_REGION")
echo "✅ VPC created: $VPC_ID"

SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" \
    --cidr-block 10.0.1.0/24 --availability-zone "${AWS_REGION}a" \
    --query "Subnet.SubnetId" --output text)
echo "✅ Subnet created: $SUBNET_ID"

IGW_ID=$(aws ec2 create-internet-gateway \
    --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
echo "✅ Internet Gateway created and attached: $IGW_ID"

ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
    --query "RouteTable.RouteTableId" --output text)
aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" \
    --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" > /dev/null
aws ec2 associate-route-table --subnet-id "$SUBNET_ID" --route-table-id "$ROUTE_TABLE_ID" > /dev/null
echo "✅ Route table configured: $ROUTE_TABLE_ID"

# === SECURITY GROUP ===
echo "🛡️ Creating Security Group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name "$TAG-sg" \
    --description "Security group for $PROJECT_NAME project" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" --output text)

aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 > /dev/null
echo "✅ Security Group created: $SG_ID"

# === EC2 INSTANCE ===
echo "🚀 Launching EC2 instance with Ubuntu 22.04 AMI ($AMI_ID)..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --subnet-id "$SUBNET_ID" \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG}]" \
    --query "Instances[0].InstanceId" --output text)

echo "✅ EC2 instance launched: $INSTANCE_ID"
echo "⏳ Waiting for instance to reach 'running' state..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "✅ Instance is running!"

# === FETCH PUBLIC IP ===
echo "🔍 Fetching Public IP..."
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

if [ "$PUBLIC_IP" == "None" ] || [ -z "$PUBLIC_IP" ]; then
    echo "❌ ERROR: Failed to fetch Public IP. Check AWS Console."
    exit 1
else
    echo "🌍 Public IP: http://$PUBLIC_IP"
fi

# === SSH SERVER CONFIGURATION ===
echo "🧱 Configuring server via SSH..."
sleep 30  # wait for instance SSH service to be ready

ssh -o StrictHostKeyChecking=no -i "$LOCAL_KEY_PATH" ubuntu@"$PUBLIC_IP" <<'EOF'
sudo apt update -y
sudo apt install -y apache2
sudo systemctl enable apache2
sudo systemctl start apache2
EOF

echo "✅ Apache web server installed successfully on instance."

# === DEPLOY WEBSITE FILES ===
if [ -f "./index.html" ]; then
    echo "📦 Deploying website files to /var/www/html..."
    scp -o StrictHostKeyChecking=no -i "$LOCAL_KEY_PATH" ./index.html ubuntu@"$PUBLIC_IP":/tmp/
    ssh -i "$LOCAL_KEY_PATH" ubuntu@"$PUBLIC_IP" "sudo mv /tmp/index.html /var/www/html/index.html && sudo systemctl restart apache2"
    echo "✅ Website deployed successfully!"
else
    echo "⚠️ index.html not found in project root — skipping deployment."
fi

echo "🎉 Deployment complete! Visit your website at: http://$PUBLIC_IP"
