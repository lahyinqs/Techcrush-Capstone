#!/bin/bash
# ci_cd_full_auto.sh — Automate linking GitHub repo and EC2 CI/CD setup

set -e
REPO="Techcrush-Capstone"
USER="lahyinqs"

echo "🔧 Ensuring Git is linked..."
git init
git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:$USER/$REPO.git

echo "📦 Adding all files and pushing..."
git add .
git commit -m "🚀 Initial automated deployment setup"
git push -u origin main

echo "🧠 Reminder: Add EC2_SSH_KEY in GitHub Secrets for CI/CD to work!"

