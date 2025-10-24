
#!/bin/bash
set -e

# ====== CONFIGURATION ======
REGION="us-east-1"                                  # Change region if necessary
KEY_NAME="techcrush-key"
INSTANCE_TYPE="t2.micro"
AMI_OWNER="099720109477"                            # Canonical (Ubuntu)
TAG="Techcrush-Web-Server"

# ====== EXISTING RESOURCES ======
VPC_ID="vpc-0fd013fe291e3a853"
SUBNET_ID="subnet-07c3ae025a3a99db4"
SG_ID="sg-012f447ebc3b7a142"

echo "✅ Using existing VPC: $VPC_ID"
echo "✅ Using existing Subnet: $SUBNET_ID"
echo "✅ Using existing Security Group: $SG_ID"

# ====== CREATE KEY PAIR ======
if [ ! -f "${KEY_NAME}.pem" ]; then
  echo "🔑 Creating EC2 key pair..."
  aws ec2 create-key-pair --key-name $KEY_NAME --query "KeyMaterial" --output text > ${KEY_NAME}.pem
  chmod 400 ${KEY_NAME}.pem
  echo "✅ Key pair created and saved as ${KEY_NAME}.pem"
else
  echo "ℹ️ Key pair ${KEY_NAME}.pem already exists, skipping creation."
fi

# ====== FETCH LATEST UBUNTU 22.04 LTS AMI ======
echo "🔍 Fetching latest Ubuntu 22.04 LTS AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners $AMI_OWNER \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text)

echo "✅ AMI_ID: $AMI_ID"

# ====== LAUNCH EC2 INSTANCE ======
echo "🚀 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "✅ Instance launched successfully: $INSTANCE_ID"

# ====== ALLOCATE AND ASSOCIATE ELASTIC IP ======
echo "🌐 Allocating Elastic IP..."
ALLOCATION_ID=$(aws ec2 allocate-address --domain vpc --query "AllocationId" --output text)
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID

# ====== FETCH INSTANCE PUBLIC IP ======
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

# ====== SAVE DETAILS ======
echo "💾 Saving instance info..."
{
  echo "Instance ID: $INSTANCE_ID"
  echo "Public IP: $PUBLIC_IP"
  echo "Elastic IP Allocation ID: $ALLOCATION_ID"
} > instance_info.txt

echo "✅ EC2 instance setup complete!"
echo "🌍 Access your instance via SSH:"
echo "ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"

