#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# --- CONFIG VARIABLES (Provided by the CI/CD environment) ---
# EC2_PRIVATE_KEY: The contents of the PEM/Private Key (stored as a Secret)
# EC2_PUBLIC_IP: The public IP or DNS name of the target EC2 instance
# REPO_URL: The URL of the repository (e.g., from the CI/CD context)
# BRANCH: The branch that was pushed (e.g., 'main')

# SSH Configuration
EC2_USER="ubuntu"
DEPLOY_DIR="/var/www/techcrush"

# --- VALIDATION ---
if [ -z "$EC2_PRIVATE_KEY" ]; then
  echo "❌ ERROR: EC2_PRIVATE_KEY is missing. Aborting."
  exit 1
fi
if [ -z "$EC2_PUBLIC_IP" ]; then
  echo "❌ ERROR: EC2_PUBLIC_IP is missing. Aborting."
  exit 1
fi

echo "🚀 Starting automated deployment to $EC2_USER@$EC2_PUBLIC_IP..."
echo "Target repo: $REPO_URL, Branch: $BRANCH"

# 1. Create a temporary key file from the secret
TEMP_KEY=$(mktemp)
echo "$EC2_PRIVATE_KEY" > "$TEMP_KEY"
chmod 400 "$TEMP_KEY"

# 2. Define the remote deployment command to be run on EC2
read -r -d '' REMOTE_SCRIPT <<EOF
set -euo pipefail

REPO_URL="$REPO_URL"
BRANCH="$BRANCH"
DEPLOY_DIR="$DEPLOY_DIR"

echo "Remote: Installing git if needed..."
if ! command -v git >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git
fi

echo "Remote: Ensuring deploy directory exists: \$DEPLOY_DIR"
if [ ! -d "\$DEPLOY_DIR" ]; then
  sudo mkdir -p "\$DEPLOY_DIR"
  sudo chown -R "\$USER":"\$USER" "\$DEPLOY_DIR"
fi

# Clone if missing, else pull (using https/ssh URL provided by CI/CD)
if [ ! -d "\$DEPLOY_DIR/.git" ]; then
  echo "Remote: Cloning fresh repo..."
  git clone --branch "\$BRANCH" --single-branch "\$REPO_URL" "\$DEPLOY_DIR"
else
  echo "Remote: Pulling latest changes..."
  cd "\$DEPLOY_DIR"
  git fetch origin "\$BRANCH"
  git reset --hard "origin/\$BRANCH"
fi

# Set correct permissions for web server (essential for PHP/HTML)
echo "Remote: Setting ownership (www-data) and permissions..."
sudo chown -R www-data:www-data "\$DEPLOY_DIR"
sudo find "\$DEPLOY_DIR" -type d -exec sudo chmod 755 {} \;
sudo find "\$DEPLOY_DIR" -type f -exec sudo chmod 644 {} \;

# Restart web service
if command -v nginx >/dev/null 2>&1; then
  echo "Remote: Restarting nginx..."
  sudo systemctl restart nginx || true
elif command -v apache2ctl >/dev/null 2>&1; then
  echo "Remote: Restarting apache2..."
  sudo systemctl restart apache2 || true
else
  echo "Remote: No web server found."
fi

echo "Remote: Deployment finished successfully."
EOF

# 3. Execute the remote script over SSH
echo "SSH -> Running remote deployment script..."
ssh -o StrictHostKeyChecking=no -i "$TEMP_KEY" "$EC2_USER"@"$EC2_PUBLIC_IP" /bin/bash -s <<SSH_EOF
$REMOTE_SCRIPT
SSH_EOF

# 4. Clean up the temporary key
rm -f "$TEMP_KEY"

echo "✅ Deployment pipeline completed."