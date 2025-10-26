#!/bin/bash
set -e  # Stop script on any error

echo "🚀 Starting Techcrush CI/CD Automation..."

# ======== CONFIGURATION ==========
PROJECT_NAME="Techcrush"
KEY_NAME="techcrush-key"
PEM_FILE="techcrush-key.pem"
REGION="us-east-1"
AMI_ID="ami-0c7217cdde317cfec"   # Ubuntu 22.04 LTS
INSTANCE_TYPE="t2.micro"
TAG="TechcrushServer"
# =================================

# --- Check for required files ---
if [ ! -f "$PEM_FILE" ]; then
  echo "❌ ERROR: PEM key file ($PEM_FILE) not found!"
  exit 1
fi

# --- Create key pair if not exists ---
echo "🔑 Checking for existing key pair..."
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "🆕 Creating new key pair..."
  aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" \
    --query "KeyMaterial" --output text > "$PEM_FILE"
  chmod 400 "$PEM_FILE"
else
  echo "ℹ️ Key pair $KEY_NAME already exists, skipping creation..."
fi

# --- Create VPC ---
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --region "$REGION" --query 'Vpc.VpcId' --output text)
echo "✅ VPC created: $VPC_ID"
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="$PROJECT_NAME-VPC"

# --- Create Subnet ---
SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 --availability-zone "${REGION}a" \
  --query 'Subnet.SubnetId' --output text)
echo "✅ Subnet created: $SUBNET_ID"

# --- Create and attach Internet Gateway ---
IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" \
  --query 'InternetGateway.InternetGatewayId' --output text)
echo "✅ Internet Gateway created: $IGW_ID"
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"

# --- Create Route Table ---
RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
aws ec2 associate-route-table --subnet-id "$SUBNET_ID" --route-table-id "$RT_ID" >/dev/null
echo "✅ Route table configured: $RT_ID"

# --- Create Security Group ---
SG_ID=$(aws ec2 create-security-group --group-name "$PROJECT_NAME-SG" \
  --description "Security group for $PROJECT_NAME" --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "✅ Security Group created: $SG_ID"

# --- Launch EC2 Instance ---
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG}]" \
  --query 'Instances[0].InstanceId' --output text)
echo "✅ EC2 instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo "⏳ Waiting for instance to be in 'running' state..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# --- Retrieve Public IP with retry ---
echo "🔍 Fetching Public IP..."
MAX_RETRIES=10
SLEEP_SECONDS=10
for ((i=1; i<=MAX_RETRIES; i++)); do
  INSTANCE_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

  if [[ "$INSTANCE_IP" != "None" && -n "$INSTANCE_IP" ]]; then
    echo "🌍 Public IP detected: http://$INSTANCE_IP"
    break
  else
    echo "⏳ Waiting for Public IP (attempt $i/$MAX_RETRIES)..."
    sleep $SLEEP_SECONDS
  fi
done

# --- Validate Public IP ---
if [[ "$INSTANCE_IP" == "None" || -z "$INSTANCE_IP" ]]; then
  echo "❌ ERROR: Failed to get Public IP after several attempts. Please check EC2 console."
  exit 1
fi

# --- Install Apache and deploy website ---
echo "🧱 Configuring server..."
ssh -o StrictHostKeyChecking=no -i "$PEM_FILE" ubuntu@$INSTANCE_IP <<'EOF'
  sudo apt update -y
  sudo apt install apache2 -y
  sudo systemctl enable apache2
  sudo systemctl start apache2
EOF
echo "✅ Apache installed successfully."

# --- Deploy website files using rsync (auto-detects updates/deletes) ---
echo "📂 Syncing website files..."
rsync -avz --delete -e "ssh -i $PEM_FILE -o StrictHostKeyChecking=no" \
  --exclude "Automation/" --exclude ".github/" \
  --exclude ".git/" --exclude "Screenshots/*.PNG" \
  ./ ubuntu@$INSTANCE_IP:/tmp/techcrush/

# --- Move to Apache web root ---
ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP <<'EOF'
  sudo rm -rf /var/www/html/*
  sudo mv /tmp/techcrush/* /var/www/html/
  sudo systemctl restart apache2
EOF

echo "✅ Website deployed and synchronized successfully!"
echo "🌐 Access your site here: http://$INSTANCE_IP"
