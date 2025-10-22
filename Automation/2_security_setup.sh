#!/bin/bash

# automation/2_security_setup.sh
# Create and configure security group

# Variables
VPC_ID=$(cat automation/vpc_id.txt)
REGION="us-east-1"
SG_NAME="Techcrush-Web-SG-Auto"

# Check if security group exists
SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$SG_NAME" --query "SecurityGroups[0].GroupId" --output text --region $REGION 2>/dev/null)
if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    echo "Creating security group..."
    SG_ID=$(aws ec2 create-security-group --group-name $SG_NAME --description "Security group for Techcrush web server (auto)" --vpc-id $VPC_ID --region $REGION --query GroupId --output text)
    aws ec2 create-tags --resources $SG_ID --tags Key=Name,Value=$SG_NAME
    echo "Security group created: $SG_ID"
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
    echo "Inbound rules added: HTTP (80), HTTPS (443), SSH (22)"
else
    echo "Security group already exists: $SG_ID"
fi

# Save output
echo $SG_ID > automation/sg_id.txt

echo "Module 2 completed!"