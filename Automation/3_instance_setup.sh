#!/bin/bash

# automation/3_instance_setup.sh
# Launch EC2 instance with key pair and Elastic IP

# Variables
SUBNET_ID=$(cat automation/subnet_id.txt)
SG_ID=$(cat automation/sg_id.txt)
REGION="us-east-1"
KEY_NAME="Techcrush-Key-Auto"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-0c55b159cbfafe1f0" # Ubuntu 22.04 LTS (verify for us-east-1)

# Check if key pair exists
KEY_EXISTS=$(aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION --query "KeyPairs[0].KeyName" --output text 2>/dev/null)
if [ "$KEY_EXISTS" != "$KEY_NAME" ]; then
    echo "Creating key pair..."
    aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query KeyMaterial --output text > automation/$KEY_NAME.pem
    chmod 400 automation/$KEY_NAME.pem
    echo "Key pair created: $KEY_NAME.pem"
else
    echo "Key pair already exists: $KEY_NAME"
fi

# Check if instance exists
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Techcrush-Web-Server-Auto" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text --region $REGION 2>/dev/null)
if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "Launching EC2 instance..."
    INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_ID --security-group-ids $SG_ID --iam-instance-profile Name=SSMInstanceProfile --region $REGION --query Instances[0].InstanceId --output text)
    aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=Techcrush-Web-Server-Auto
    echo "EC2 instance launched: $INSTANCE_ID"
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
    echo "Instance is running"
else
    echo "Instance already exists: $INSTANCE_ID"
fi

# Check if Elastic IP exists
PUBLIC_IP=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=Techcrush-EIP-Auto" --query "Addresses[0].PublicIp" --output text --region $REGION 2>/dev/null)
if [ "$PUBLIC_IP" == "None" ] || [ -z "$PUBLIC_IP" ]; then
    echo "Allocating Elastic IP..."
    ALLOCATION_ID=$(aws ec2 allocate-address --domain vpc --region $REGION --query AllocationId --output text)
    aws ec2 create-tags --resources $ALLOCATION_ID --tags Key=Name,Value=Techcrush-EIP-Auto
    aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID --region $REGION
    PUBLIC_IP=$(aws ec2 describe-addresses --allocation-ids $ALLOCATION_ID --region $REGION --query Addresses[0].PublicIp --output text)
    echo "Elastic IP allocated and associated: $PUBLIC_IP"
else
    echo "Elastic IP already exists: $PUBLIC_IP"
fi

# Save outputs
echo $PUBLIC_IP > automation/public_ip.txt
echo $INSTANCE_ID > automation/instance_id.txt

echo "Module 3 completed!"