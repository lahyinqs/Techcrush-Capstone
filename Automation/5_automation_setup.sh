#!/bin/bash

# automation/5_automation_setup.sh
# Set up GitHub Actions workflow for automation

# Variables
GITHUB_USER="lahyinqs" # Replace with your GitHub username
WORKFLOW_DIR="../.github/workflows"
WORKFLOW_FILE="deploy.yml"

# Create GitHub Actions workflow
echo "Creating GitHub Actions workflow..."
mkdir -p $WORKFLOW_DIR
cat << EOF > $WORKFLOW_DIR/$WORKFLOW_FILE
name: Deploy Techcrush Website

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      - name: Set up AWS CLI
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: \${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: \${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Run Network Setup
        run: bash automation/1_network_setup.sh
      - name: Run Security Setup
        run: bash automation/2_security_setup.sh
      - name: Run EC2 Instance Setup
        run: bash automation/3_instance_setup.sh
      - name: Run Web Server Setup
        run: bash automation/4_webserver_setup.sh
EOF

echo "Module 5 completed! Workflow created at $WORKFLOW_DIR/$WORKFLOW_FILE"
echo "Next steps:"
echo "1. Add AWS credentials to GitHub Secrets:"
echo "   - Go to https://github.com/$GITHUB_USER/Techcrush-Capstone/settings/secrets/actions"
echo "   - Add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
echo "2. Commit and push changes to GitHub"
echo "3. Run the workflow from the Actions tab"
