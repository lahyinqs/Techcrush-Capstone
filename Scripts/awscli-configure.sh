#!/bin/bash
# ===================================================
# AWS CLI Configuration Script (using .env file)
# ===================================================

# Load environment variables
if [ -f awscli.env ]; then
  source awscli.env
else
  echo "❌ awscli.env file not found!"
  exit 1
fi

echo "🧩 Configuring AWS CLI using environment file..."

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$AWS_REGION"
aws configure set default.output "$AWS_OUTPUT"

echo "✅ AWS CLI configuration complete!"

# Verify setup
aws sts get-caller-identity

