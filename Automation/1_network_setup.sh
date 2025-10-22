#!/bin/bash

# automation/1_network_setup.sh
# Create VPC, subnet, Internet Gateway, and route table

# Variables
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
REGION="us-east-1"
VPC_NAME="Techcrush-VPC-Auto"
SUBNET_NAME="Techcrush-Public-Subnet-Auto"
IGW_NAME="Techcrush-IGW-Auto"
RT_NAME="Techcrush-RouteTable-Auto"

# Check if VPC exists
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query "Vpcs[0].VpcId" --output text --region $REGION 2>/dev/null)
if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "Creating VPC..."
    VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query Vpc.VpcId --output text)
    aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME
    echo "VPC created: $VPC_ID"
else
    echo "VPC already exists: $VPC_ID"
fi

# Check if subnet exists
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$SUBNET_NAME" --query "Subnets[0].SubnetId" --output text --region $REGION 2>/dev/null)
if [ "$SUBNET_ID" == "None" ] || [ -z "$SUBNET_ID" ]; then
    echo "Creating public subnet..."
    SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_CIDR --region $REGION --query Subnet.SubnetId --output text)
    aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=$SUBNET_NAME
    echo "Subnet created: $SUBNET_ID"
else
    echo "Subnet already exists: $SUBNET_ID"
fi

# Check if Internet Gateway exists
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=$IGW_NAME" --query "InternetGateways[0].InternetGatewayId" --output text --region $REGION 2>/dev/null)
if [ "$IGW_ID" == "None" ] || [ -z "$IGW_ID" ]; then
    echo "Creating Internet Gateway..."
    IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query InternetGateway.InternetGatewayId --output text)
    aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$IGW_NAME
    echo "Internet Gateway created: $IGW_ID"
    aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
    echo "Internet Gateway attached to VPC"
else
    echo "Internet Gateway already exists: $IGW_ID"
fi

# Check if route table exists
RT_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$RT_NAME" --query "RouteTables[0].RouteTableId" --output text --region $REGION 2>/dev/null)
if [ "$RT_ID" == "None" ] || [ -z "$RT_ID" ]; then
    echo "Creating route table..."
    RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query RouteTable.RouteTableId --output text)
    aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=$RT_NAME
    echo "Route table created: $RT_ID"
    aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
    echo "Route to Internet Gateway added"
    aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RT_ID --region $REGION
    echo "Route table associated with subnet"
else
    echo "Route table already exists: $RT_ID"
fi

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region $REGION
echo "Public IP auto-assignment enabled for subnet"

# Save outputs
echo $VPC_ID > automation/vpc_id.txt
echo $SUBNET_ID > automation/subnet_id.txt

echo "Module 1 completed!"