#!/bin/bash
# ========================================================
# MODULE 2: Security Configuration for Techcrush Project
# ========================================================

# ---- CONFIGURATION ----
PROJECT_NAME="Techcrush"
REGION="us-east-1"

# ---- GET VPC ID ----
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-VPC" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
  echo "❌ Error: VPC not found. Run Module 1 first."
  exit 1
fi

echo "✅ Found VPC: $VPC_ID"

# ---- CREATE SECURITY GROUP FOR WEB SERVER ----
echo "Creating Web Server Security Group..."
WEB_SG_ID=$(aws ec2 create-security-group \
  --group-name ${PROJECT_NAME}-Web-SG \
  --description "Security group for ${PROJECT_NAME} Web Server" \
  --vpc-id $VPC_ID \
  --query "GroupId" \
  --output text)

aws ec2 create-tags --resources $WEB_SG_ID --tags Key=Name,Value=${PROJECT_NAME}-Web-SG
echo "✅ Created Web Security Group: $WEB_SG_ID"

# ---- ALLOW INBOUND TRAFFIC (HTTP, HTTPS, SSH) ----
aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG_ID \
  --ip-permissions '[
    {
      "IpProtocol": "tcp",
      "FromPort": 22,
      "ToPort": 22,
      "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow SSH"}]
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 80,
      "ToPort": 80,
      "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow HTTP"}]
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 443,
      "ToPort": 443,
      "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow HTTPS"}]
    }
  ]'
echo "✅ Inbound Rules configured (SSH, HTTP, HTTPS)"

# ---- ALLOW ALL OUTBOUND TRAFFIC ----
aws ec2 authorize-security-group-egress \
  --group-id $WEB_SG_ID \
  --ip-permissions '[
    {
      "IpProtocol": "-1",
      "IpRanges": [{"CidrIp": "0.0.0.0/0"}]
    }
  ]'
echo "✅ Outbound Rules configured (Allow all traffic)"

# ---- SUMMARY ----
echo "==========================================="
echo "✅ MODULE 2 COMPLETE: SECURITY CONFIGURATION DONE!"
echo "VPC ID:     $VPC_ID"
echo "WEB SG ID:  $WEB_SG_ID"
echo "==========================================="

