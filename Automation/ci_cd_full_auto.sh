#!/bin/bash
set -e

echo "🚀 Starting Techcrush CI/CD Automation..."

# ============================================
# 1️⃣ ENVIRONMENT VARIABLES
# ============================================
AWS_REGION="us-east-1"
KEY_NAME="techcrush-key"
LOCAL_KEY_PATH="/c/Techcrush/techcrush-key.pem"
AMI_ID=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-2.0.*-x86_64-gp2" \
              "Name=state,Values=available" \
    --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" \
    --output text)

INSTANCE_TYPE="t2.micro"
TAG_NAME="Techcrush-Capstone"
VPC_NAME="Techcrush-VPC"
SUBNET_CIDR="10.0.1.0/24"
SECURITY_GROUP_NAME="techcrush-sg"
HTML_PATH="index.html"

# ============================================
# 2️⃣ CREATE OR REUSE KEY PAIR
# ============================================
echo "🔑 Checking for existing key pair..."
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "ℹ️ Key pair $KEY_NAME already exists, skipping creation..."
else
    echo "🆕 Creating new key pair..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" \
        --query "KeyMaterial" --output text > "$LOCAL_KEY_PATH"
    chmod 400 "$LOCAL_KEY_PATH"
fi

# ============================================
# 3️⃣ CREATE NETWORKING RESOURCES
# ============================================
echo "🌐 Setting up VPC, Subnet, IGW, and Route Table..."

VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --query "Vpc.VpcId" --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=$VPC_NAME
echo "✅ VPC created: $VPC_ID"

SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$SUBNET_CIDR" \
    --query "Subnet.SubnetId" --output text --region "$AWS_REGION")
echo "✅ Subnet created: $SUBNET_ID"

IGW_ID=$(aws ec2 create-internet-gateway \
    --query "InternetGateway.InternetGatewayId" --output text --region "$AWS_REGION")
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
echo "✅ Internet Gateway created: $IGW_ID"

ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query "RouteTable.RouteTableId" --output text --region "$AWS_REGION")
aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --subnet-id "$SUBNET_ID" --route-table-id "$ROUTE_TABLE_ID"
echo "✅ Route table configured: $ROUTE_TABLE_ID"

# ============================================
# 4️⃣ CREATE SECURITY GROUP
# ============================================
echo "🛡️ Creating Security Group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Techcrush web access" \
    --vpc-id "$VPC_ID" \
    --region "$AWS_REGION" \
    --query "GroupId" --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
    --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$AWS_REGION"
echo "✅ Security Group created: $SG_ID"

# ============================================
# 5️⃣ LAUNCH EC2 INSTANCE
# ============================================
echo "🚀 Launching EC2 instance..."

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --subnet-id "$SUBNET_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
    --query "Instances[0].InstanceId" \
    --region "$AWS_REGION" --output text)

echo "✅ EC2 instance launched: $INSTANCE_ID"

echo "⏳ Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

echo "🔍 Fetching Public IP..."
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --region "$AWS_REGION" \
    --output text)

if [ "$PUBLIC_IP" == "None" ] || [ -z "$PUBLIC_IP" ]; then
    echo "❌ ERROR: Failed to retrieve Public IP."
    exit 1
fi

echo "🌍 Public IP: http://$PUBLIC_IP"

# ============================================
# 6️⃣ DEPLOY WEBSITE FILES
# ============================================
echo "📤 Deploying website to EC2..."

if [ ! -f "$LOCAL_KEY_PATH" ]; then
    echo "❌ ERROR: PEM key not found at $LOCAL_KEY_PATH"
    exit 1
fi

# Wait briefly for SSH to become available
sleep 20

scp -i "$LOCAL_KEY_PATH" -o StrictHostKeyChecking=no *.html ec2-user@"$PUBLIC_IP":/home/ec2-user/

ssh -i "$LOCAL_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@"$PUBLIC_IP" <<EOF
    sudo yum update -y
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd
    sudo mv /home/ec2-user/*.html /var/www/html/
    sudo chown apache:apache /var/www/html/*.html
EOF

echo "✅ Deployment complete! Visit your site at: http://$PUBLIC_IP"

# ============================================
# 7️⃣ AUTO DETECT FILE CHANGES (LOCAL)
# ============================================
echo "🔍 Checking for local file changes..."
CHANGED_FILES=$(git status --porcelain | grep ".html" || true)

if [ -n "$CHANGED_FILES" ]; then
    echo "🌀 Detected updates/deletions in HTML files..."
    scp -i "$LOCAL_KEY_PATH" -o StrictHostKeyChecking=no *.html ec2-user@"$PUBLIC_IP":/home/ec2-user/
    ssh -i "$LOCAL_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@"$PUBLIC_IP" "sudo mv /home/ec2-user/*.html /var/www/html/"
    echo "♻️ Website refreshed with latest changes!"
else
    echo "✅ No changes detected. Website already up-to-date."
fi

echo "🎉 Techcrush CI/CD pipeline executed successfully!"
