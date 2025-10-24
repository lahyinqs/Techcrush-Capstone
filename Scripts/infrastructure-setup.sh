#!/bin/bash
# ========================================================
# MODULE 1: Network Infrastructure Setup for Techcrush
# ========================================================

# ---- CONFIGURATION ----
PROJECT_NAME="Techcrush"
REGION="us-east-1"
CIDR_BLOCK="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"

# ---- CREATE VPC ----
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $CIDR_BLOCK \
  --region $REGION \
  --query "Vpc.VpcId" \
  --output text)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=${PROJECT_NAME}-VPC
echo "✅ VPC created: $VPC_ID"

# ---- CREATE PUBLIC SUBNET ----
echo "Creating Public Subnet..."
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --query "Subnet.SubnetId" \
  --output text)

aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=${PROJECT_NAME}-Public-Subnet
echo "✅ Subnet created: $SUBNET_ID"

# ---- CREATE INTERNET GATEWAY ----
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=${PROJECT_NAME}-IGW
echo "✅ Internet Gateway created and attached: $IGW_ID"

# ---- CREATE ROUTE TABLE ----
echo "Creating Route Table..."
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 create-tags --resources $RTB_ID --tags Key=Name,Value=${PROJECT_NAME}-Public-RT
echo "✅ Route Table created: $RTB_ID"

# ---- ADD INTERNET ROUTE ----
aws ec2 create-route \
  --route-table-id $RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID
echo "✅ Added Internet Route to Route Table"

# ---- ASSOCIATE SUBNET WITH ROUTE TABLE ----
aws ec2 associate-route-table \
  --subnet-id $SUBNET_ID \
  --route-table-id $RTB_ID
echo "✅ Subnet associated with Route Table"

# ---- ENABLE AUTO-ASSIGN PUBLIC IP ----
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch
echo "✅ Enabled auto-assign public IP for subnet"

# ---- SUMMARY ----
echo "==========================================="
echo "✅ MODULE 1 COMPLETE: NETWORK SETUP DONE!"
echo "VPC ID:        $VPC_ID"
echo "Subnet ID:     $SUBNET_ID"
echo "IGW ID:        $IGW_ID"
echo "Route Table:   $RTB_ID"
echo "==========================================="

