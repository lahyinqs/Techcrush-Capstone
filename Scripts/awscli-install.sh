#!/bin/bash
# ================================================
# AWS CLI v2 Installation Script for Ubuntu/Debian
# Author: Olayinka Oyero Team
# ================================================

echo "🚀 Starting AWS CLI installation..."

# Step 1: Remove any old AWS CLI
echo "🧹 Removing any old AWS CLI installation..."
sudo apt remove awscli -y >/dev/null 2>&1

# Step 2: Update system and install unzip
echo "🔄 Updating system and installing unzip..."
sudo apt update -y >/dev/null 2>&1
sudo apt install unzip curl -y >/dev/null 2>&1

# Step 3: Download AWS CLI v2
echo "📦 Downloading AWS CLI v2 installer..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Step 4: Unzip the package
echo "📂 Unzipping installer..."
unzip -o awscliv2.zip >/dev/null 2>&1

# Step 5: Install AWS CLI
echo "⚙️ Installing AWS CLI v2..."
sudo ./aws/install >/dev/null 2>&1

# Step 6: Verify installation
if command -v aws >/dev/null 2>&1; then
    echo "✅ AWS CLI installed successfully!"
    aws --version
else
    echo "❌ Installation failed. Please check your internet connection or permissions."
    exit 1
fi

# Step 7: Cleanup
echo "🧽 Cleaning up temporary files..."
rm -rf aws awscliv2.zip

# Step 8: Configuration prompt
echo ""
echo "⚙️ Now configure your AWS credentials using the command below:"
echo "   aws configure"
echo ""
echo "Enter your Access Key, Secret Key, Default Region (e.g., us-east-1), and output format (e.g., json)."
echo ""
echo "🎯 Setup complete!"

