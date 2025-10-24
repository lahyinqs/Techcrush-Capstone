#!/bin/bash
set -e
echo "🚀 Starting Techcrush CI/CD automation..."

PROJECT_NAME="Techcrush"
KEY_NAME="techcrush-key"
KEY_PATH="$KEY_NAME.pem"
REGION="us-east-1"

echo "✅ Configuration loaded for project: $PROJECT_NAME"

# === 1️⃣ Key Pair Setup ===
echo "🔑 Checking for existing key pair..."
if aws ec2 describe-key-pairs --key-name "$KEY_NAME" --region $REGION >/dev/null 2>&1; then
  echo "ℹ️ Key pair $KEY_NAME already exists, skipping creation..."
else
  echo "✅ Creating new key pair: $KEY_NAME"
  aws ec2 create-key-pair --key-name "$KEY_NAME" --region $REGION \
    --query 'KeyMaterial' --output text > "$KEY_PATH"
  chmod 400 "$KEY_PATH"
  echo "🔐 Key saved to $KEY_PATH with restricted permissions."
fi

# === 2️⃣ Create VPC ===
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --region $REGION --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support "{\"Value\":true}" --region $REGION
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames "{\"Value\":true}" --region $REGION
echo "✅ VPC created: $VPC_ID"

# === 3️⃣ Create Subnet ===
SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 \
  --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text --region $REGION)
echo "✅ Subnet created: $SUBNET_ID"

# === 4️⃣ Internet Gateway ===
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region $REGION
echo "✅ Internet Gateway created and attached: $IGW_ID"

# === 5️⃣ Route Table ===
RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region $REGION --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region $REGION
aws ec2 associate-route-table --subnet-id "$SUBNET_ID" --route-table-id "$RTB_ID" --region $REGION
echo "✅ Route table configured: $RTB_ID"

# === 6️⃣ Security Group ===
SG_ID=$(aws ec2 create-security-group --group-name "${PROJECT_NAME}-SG" --description "Security group for $PROJECT_NAME" \
  --vpc-id "$VPC_ID" --region $REGION --query 'GroupId' --output text)
echo "✅ Security Group created: $SG_ID"

# Allow SSH (22) and HTTP (80)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
echo "✅ Inbound rules added for ports 22 and 80"

# === 7️⃣ Launch EC2 Instance ===
echo "🖥️ Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --count 1 \
  --instance-type t2.micro \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ EC2 instance launched: $INSTANCE_ID"

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region $REGION
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "🌍 Public IP: http://$PUBLIC_IP"

# === 8️⃣ Deploy Static Website Files ===
echo "📦 Deploying website files..."
chmod 400 "$KEY_PATH"

echo "⏳ Waiting for EC2 to be fully ready..."
sleep 30

scp -i "$KEY_PATH" -o StrictHostKeyChecking=no -r index.html Aboutus.html Contact-us.html ubuntu@"$PUBLIC_IP":/tmp/ || {
  echo "❌ SCP failed — check network or SSH key."
  exit 1
}

ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" <<'EOF'
  set -e
  sudo apt update -y
  sudo apt install apache2 -y
  sudo mv /tmp/*.html /var/www/html/
  sudo systemctl restart apache2
  echo "✅ Website deployed successfully!"
EOF

echo "🎉 Deployment completed successfully!"
echo "🌐 Access your website at: http://$PUBLIC_IP"
