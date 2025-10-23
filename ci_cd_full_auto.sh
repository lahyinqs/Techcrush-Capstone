#!/bin/bash
set -e

# === CONFIGURATION ===
REPO="lahyinqs/Techcrush-Capstone"
EC2_HOST="54.83.163.104"
EC2_USER="ubuntu"
SSH_KEY_PATH="$HOME/.ssh/techcrush_cicd_key"

echo "🚀 Starting full Techcrush CI/CD setup..."

# --- STEP 1: Generate SSH Keypair if not exists ---
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "🔑 Generating SSH keypair for GitHub Actions..."
    ssh-keygen -t rsa -b 4096 -C "techcrush-cicd" -f "$SSH_KEY_PATH" -N ""
else
    echo "✅ SSH key already exists at $SSH_KEY_PATH"
fi

# --- STEP 2: Add Public Key to GitHub Account ---
PUB_KEY=$(cat "$SSH_KEY_PATH.pub")
echo "📤 Uploading SSH public key to GitHub account..."
gh ssh-key add "$SSH_KEY_PATH.pub" -t "Techcrush-CI/CD Key"

# --- STEP 3: Create GitHub Secrets for Actions ---
echo "🔐 Adding GitHub Action Secrets..."
gh secret set EC2_HOST -b"$EC2_HOST" -R "$REPO"
gh secret set EC2_USER -b"$EC2_USER" -R "$REPO"
gh secret set EC2_SSH_KEY -b"$(cat $SSH_KEY_PATH)" -R "$REPO"

echo "✅ GitHub Secrets successfully created for $REPO"

# --- STEP 4: Setup GitHub Actions Workflow ---
mkdir -p .github/workflows
cat > .github/workflows/deploy.yml <<'EOF'
name: Techcrush CI/CD Deploy

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Copy files to EC2
        env:
          EC2_HOST: ${{ secrets.EC2_HOST }}
          EC2_USER: ${{ secrets.EC2_USER }}
          EC2_SSH_KEY: ${{ secrets.EC2_SSH_KEY }}
        run: |
          echo "$EC2_SSH_KEY" > private_key.pem
          chmod 600 private_key.pem
          rsync -avz -e "ssh -o StrictHostKeyChecking=no -i private_key.pem" ./ $EC2_USER@$EC2_HOST:/var/www/html/
          ssh -i private_key.pem -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST "sudo systemctl restart nginx"
          rm -f private_key.pem
EOF

echo "✅ GitHub Actions workflow created."

# --- STEP 5: Commit and Push Changes ---
echo "📦 Pushing files to GitHub repository..."
git add .
git commit -m "Added Techcrush CI/CD pipeline"
git push origin main

echo "🎉 CI/CD pipeline setup complete!"
echo "Every time you push to main, your website will auto-deploy to EC2: http://$EC2_HOST/"
