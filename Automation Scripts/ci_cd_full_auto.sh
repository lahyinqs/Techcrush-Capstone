#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# === CONFIG ===
KEY_PATH="techcrush-key.pem"
EC2_USER="ubuntu"
DEPLOY_DIR="/var/www/techcrush"
REPO_URL=$(git config --get remote.origin.url || echo "")
BRANCH="${BRANCH:-main}"
AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TAG_NAME="${INSTANCE_TAG_NAME:-Techcrush}"

echo "🚀 Starting CI/CD deploy script (git-pull -> EC2)..."

# === PRECHECKS ===
if [ ! -f "$KEY_PATH" ]; then
  echo "❌ ERROR: PEM key file not found at $KEY_PATH"
  exit 1
fi
chmod 400 "$KEY_PATH" || true

if [ -z "$REPO_URL" ]; then
  echo "❌ ERROR: Could not detect repository URL from git remote. Ensure this script runs inside your repo."
  exit 1
fi

echo "Detected repo: $REPO_URL"
echo "Target branch: $BRANCH"
echo "AWS region: $AWS_REGION"
echo "Looking for running EC2 with tag Name=$INSTANCE_TAG_NAME..."

# === FIND EC2 PUBLIC IP (by tag Name=Techcrush and state=running) ===
PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=${INSTANCE_TAG_NAME}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text || true)

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
  echo "❌ ERROR: No running EC2 instance found with tag Name=${INSTANCE_TAG_NAME} in region ${AWS_REGION}."
  echo "Please start the instance or ensure the Name tag matches."
  exit 1
fi

echo "✅ Found EC2 public IP: $PUBLIC_IP"

# === PREPARE REMOTE COMMANDS ===
# This here-doc will run on the EC2 instance and perform clone/pull, permissions, and service restart.
read -r -d '' REMOTE_SCRIPT <<'EOF' || true
set -euo pipefail

REPO_URL="$1"
BRANCH="$2"
DEPLOY_DIR="$3"

echo "Remote: ensure git is installed..."
if ! command -v git >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git
fi

echo "Remote: creating deploy directory if missing: $DEPLOY_DIR"
if [ ! -d "$DEPLOY_DIR" ]; then
  sudo mkdir -p "$DEPLOY_DIR"
  sudo chown "$USER":"$USER" "$DEPLOY_DIR"
fi

# Clone if missing, else pull
if [ ! -d "$DEPLOY_DIR/.git" ]; then
  echo "Remote: cloning repo into $DEPLOY_DIR (branch: $BRANCH)..."
  git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$DEPLOY_DIR"
else
  echo "Remote: updating existing repo (git fetch & reset) in $DEPLOY_DIR..."
  cd "$DEPLOY_DIR"
  git fetch origin "$BRANCH"
  git reset --hard "origin/$BRANCH"
fi

# Ensure correct permissions for web server (www-data)
echo "Remote: setting ownership and permissions..."
sudo chown -R www-data:www-data "$DEPLOY_DIR"
sudo find "$DEPLOY_DIR" -type d -exec sudo chmod 755 {} \;
sudo find "$DEPLOY_DIR" -type f -exec sudo chmod 644 {} \;

# Restart web service: prefer nginx, fallback to apache2
if command -v nginx >/dev/null 2>&1; then
  echo "Remote: restarting nginx..."
  sudo systemctl restart nginx || sudo service nginx restart || true
elif command -v apache2ctl >/dev/null 2>&1; then
  echo "Remote: restarting apache2..."
  sudo systemctl restart apache2 || sudo service apache2 restart || true
else
  echo "Remote: no nginx or apache2 found - you may need to install and configure your webserver."
fi

echo "Remote: deployment finished."
EOF

# === RUN REMOTE SCRIPT OVER SSH ===
echo "SSH -> ubuntu@${PUBLIC_IP} (running remote deploy script)..."

# Use ssh with StrictHostKeyChecking=no to avoid interactive prompt on new host
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$EC2_USER"@"$PUBLIC_IP" /bin/bash -s -- "$REPO_URL" "$BRANCH" "$DEPLOY_DIR" <<'SSH_EOF'
'"$REMOTE_SCRIPT"'
SSH_EOF

echo "✅ Deployment completed. Visit your site or check /var/www/techcrush on EC2."
