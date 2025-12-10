# ----------------------------------------
# 1. Terraform Backend & Provider
# ----------------------------------------
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ----------------------------------------
# 2. Data Lookup (Dynamic AZs)
# ----------------------------------------
data "aws_availability_zones" "available" {}

# ----------------------------------------
# 3. VPC Module Call
# ----------------------------------------
module "vpc" {
  source           = "./modules/vpc"
  project_name     = var.project_name
  vpc_cidr         = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  azs              = slice(data.aws_availability_zones.available.names, 0, 2)
  region           = var.region
}

# ----------------------------------------
# 4. ECS Application Service Module Call
# ----------------------------------------
module "app_service" {
  source                  = "./modules/app-service"
  project_name            = var.project_name
  
  # VPC Networking
  vpc_id                  = module.vpc.vpc_id
  public_subnets          = module.vpc.public_subnets
  private_subnets         = module.vpc.private_subnets
  
  # Application Config
  container_image         = var.container_image
  container_port          = var.app_port
  fargate_cpu             = 256
  fargate_memory          = 512
  desired_count           = 1
}

# ----------------------------------------
# 5. Outputs
# ----------------------------------------
output "service_url" {
  description = "The public URL of the Application Load Balancer."
  value       = "http://${module.app_service.alb_dns_name}"
}