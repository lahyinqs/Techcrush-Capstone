# 🧠 Techcrush Automation Setup

This folder contains all scripts for automated static website deployment to AWS EC2.

## ⚙️ Files
| File | Description |
|------|--------------|
| `setup_server.sh` | Installs Nginx and deploys the static site to `/usr/share/nginx/html` |
| `deploy.yml` | GitHub Actions workflow — triggers on every push to `main` |
| `ci_cd_full_auto.sh` | Optional helper to push automation setup to GitHub |
| `README.md` | This documentation file |

## 🔑 Prerequisites
1. Your EC2 instance must allow SSH (port 22) and HTTP (port 80).
2. Upload your private SSH key to GitHub Secrets as `EC2_SSH_KEY`.
3. Push new commits to the `main` branch — GitHub Actions will auto-deploy to EC2.

## 🚀 Deployment Flow
1. Developer commits changes to the repo.  
2. GitHub Actions runs `deploy.yml`.  
3. Files are securely transferred to EC2 via SSH.  
4. `setup_server.sh` runs automatically to update Nginx and publish the site.  
5. Visit your live site at **http://54.83.163.104/**.

Secret key added 
---

🧩 **Maintainer:** [@lahyinqs](https://github.com/lahyinqs)
 
 Techcrush Cohort 3 Capstone Project updated 1
