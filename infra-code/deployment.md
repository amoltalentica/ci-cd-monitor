#######********Deployment Guide — CI/CD Monitor App********######

🔹 Overview

This document describes how to deploy the CI/CD Monitor App from GitHub repo
 to AWS using Terraform and GitHub Actions.

The setup will:

Provision AWS infra (VPC, Subnet, Security Group, EC2, ECR) using Terraform

Build & push the Docker image to ECR via GitHub Actions

Run the containerized app on EC2 (publicly accessible via IP)

🔹 1. Prerequisites

AWS Account with admin privileges

Install locally:

Terraform
 (≥ 1.3)

AWS CLI
 (≥ v2)

GitHub repo cloned locally

🔹 2. AWS Setup

Create an IAM user (e.g. ci-cd-deployer) in AWS with programmatic access.

Attach AdministratorAccess policy (for demo; restrict in prod).

Save:

Access Key ID

Secret Access Key

🔹 3. GitHub Secrets Configuration

In your repo: Settings → Secrets and variables → Actions → New repository secret

Add the following:

Secret Name	Value
AWS_ACCESS_KEY_ID	Your IAM user Access Key ID
AWS_SECRET_ACCESS_KEY	Your IAM user Secret Key
AWS_REGION	e.g. us-east-1
TF_VAR_aws_region	Same as above (e.g. us-east-1)
TF_VAR_ssh_public_key	Your public SSH key (~/.ssh/id_rsa.pub)
🔹 4. Terraform Configuration

Folder structure:

infra/
  provider.tf
  variables.tf
  main.tf
  outputs.tf
  terraform.tfvars   # your custom values

Apply Terraform From your local machine:

cd infra
terraform init
terraform plan
terraform apply -auto-approve

After Terraform apply:

Get the EC2 Public IP: terraform output public_ip

Open in browser: http://<public_ip>


##########*******The CI/CD Monitor App should now be running 🎉*******##########