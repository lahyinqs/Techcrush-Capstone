cat << EOF > ~/Techcrush-Capstone/README.md
# Techcrush Capstone Project

This project deploys a static website on AWS EC2 with NGINX, automated via GitHub Actions.

## Project Structure
- \`1_network_setup.sh\` to \`4_webserver_setup.sh\`: Manual scripts for VPC, security group, EC2, and NGINX setup.
- \`5_automation_setup.sh\`: Sets up the original repository (manual setup).
- \`automation/\`: Scripts for automated deployment.
- \`screenshots/\`: Project screenshots.

## Screenshots
- Website: ![Website](screenshots/website_output.png)
- EC2 Console: ![EC2](screenshots/ec2_console.png)
- GitHub Actions: ![Workflow](screenshots/github_actions.png)

## Setup Instructions
1. Clone: \`git clone https://github.com/<lahyinqs>/Techcrush-Capstone.git\`
2. Add AWS secrets to GitHub (\`AWS_ACCESS_KEY_ID\`, \`AWS_SECRET_ACCESS_KEY\`).
3. Run the workflow from the Actions tab.
4. Visit the EC2 public IP in a browser.

## Automation
- Run \`automation/5_automation_setup.sh\` to set up GitHub Actions.
- Workflow (\`deploy.yml\`) automates Modules 1–4 in the \`automation/\` folder.

## Requirements
- AWS CLI
- GitHub CLI
- Git
- IAM role \`SSMInstanceProfile\` for EC2
EOF