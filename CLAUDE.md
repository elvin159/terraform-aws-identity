# About

This directory will house a modular terraform module. It needs to be production quality. It must be used to assume that we will be using multiple AWS accounts for development staging and production. One AWS account per environment. It needs to abide by the keep it simple stupid principle of system administration. Terraform code needs to be clean. Versions need to be pinned. We will be using OIDC and DO NOT rely on AWS secrets 

# Function

This module will create IRSA roles for Cluster Autoscaler, ALB Controller, ExternalDNS, and External Secrets

# github actions

 create a github workflow file in this folder. I want it simple. Seperate jobs to make sure terraform fmt is ran, validate, and a plan. It will OIDC to
  authenticate when planning. I want the terraform plan to only happen when there is a PR opened or when new commits are push to the branch that wants to be merged into main. I want a terraform apply to only happen when the merge happens with proper approvals. 



