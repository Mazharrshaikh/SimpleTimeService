# SimpleTimeService

A lightweight microservice that returns the current UTC timestamp and visitor's IP address, deployed to AWS ECS Fargate using Terraform.

---

##  Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Application](#application)
- [Docker](#docker)
- [Terraform Infrastructure](#terraform-infrastructure)
- [Deployment Guide](#deployment-guide)
- [Usage & Commands](#usage--commands)
- [API Reference](#api-reference)
- [Security](#security)

---

##  Overview

SimpleTimeService is a minimal Python Flask-based web service

**What it does:** Returns a JSON response with the current UTC timestamp and the client's IP address.

---

## 🏗️ Architecture

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                        AWS VPC                          │
                                    │                                                         │
┌──────────┐      ┌─────────────────┼───────────────┐       ┌─────────────────────────────────┤
│          │      │  Public Subnet (AZ-1 & AZ-2)    │       │  Private Subnet (AZ-1 & AZ-2)   │
│  Users   │──────│                                 │       │                                 │
│          │ :80  │  ┌───────────────────────────┐  │       │  ┌───────────────────────────┐  │
└──────────┘      │  │  Application Load Balancer│──┼───────┼─▶│   ECS Fargate Tasks       │  │
                  │  │         (ALB)             │  │ :8080 │  │   (SimpleTimeService)     │  │
                  │  └───────────────────────────┘  │       │  └───────────────────────────┘  │
                  │                                 │       │              │                  │
                  │  ┌───────────────────────────┐  │       │              │ Image Pull       │
                  │  │       NAT Gateway         │◀─┼───────┼──────────────┘                  │
                  │  └───────────────────────────┘  │       │                                 │
                  │              │                  │       │                                 │
                  └──────────────┼──────────────────┘       └─────────────────────────────────┤
                                 │                                                            │
                                 ▼                                                            │
                          ┌─────────────┐                                                     │
                          │ Docker Hub  │                                                     │
                          └─────────────┘                                                     │
                                    └─────────────────────────────────────────────────────────┘
```

### Infrastructure Components

| Component | Description |
|-----------|-------------|
| **VPC Module** | Creates a highly available network across 2 Availability Zones with public and private subnets |
| **Public Subnets** | Hosts the Application Load Balancer and NAT Gateway |
| **Private Subnets** | Hosts ECS Fargate tasks (isolated from direct internet access) |
| **NAT Gateway** | Allows Fargate tasks to pull Docker images from public registries |
| **ALB** | Internet-facing load balancer that routes traffic to Fargate tasks |
| **ECS Cluster** | Manages the Fargate task definitions and services |

---

## Application

### Tech Stack

- **Language:** Python 3.12
- **Framework:** Flask 2.3.3
- **WSGI Server:** Gunicorn 21.2.0

### Project Structure

```
SimpleTimeService/
├── app.py                 # Flask application
├── Dockerfile             # Container definition
├── requirements.txt       # Python dependencies
├── .gitignore            # Git ignore patterns
├── .dockerignore         # Docker build ignore patterns
├── README.md             # This file
└── terraform/            # Infrastructure as Code
    ├── main.tf           # Root module
    ├── variables.tf      # Input variables
    ├── outputs.tf        # Output values
    └── modules/
        ├── vpc/          # VPC networking module
        └── app-service/  # ECS, ALB, IAM module
```

---

##  Docker

### Quick Start (Local)

**Build the image:**
```bash
docker build -t simpletimeservice .
```

**Run the container:**
```bash
docker run -d -p 8080:8080 simpletimeservice
```

**Test locally:**
```bash
curl http://localhost:8080/
```

### Image Features

| Feature | Details |
|---------|---------|
| Base Image | `python:3.12-slim` (minimal footprint) |
| User | Runs as non-root `appuser` |
| Server | Gunicorn WSGI (production-ready) |
| Port | 8080 |

### Publish to Docker Hub

```bash
# Tag the image
docker tag simpletimeservice <your-dockerhub-username>/simpletimeservice:latest

# Login to Docker Hub
docker login

# Push the image
docker push <your-dockerhub-username>/simpletimeservice:latest
```

### Verify Non-root User

```bash
docker exec <container_id> whoami
# Output: appuser
```

---

##  Terraform Infrastructure

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- AWS Account with appropriate permissions

### AWS Authentication

Terraform uses the AWS Default Credential Chain. Configure your credentials:

```bash
aws configure
```

This stores credentials in `~/.aws/credentials`, which Terraform automatically uses.

### Module Overview

#### VPC Module
Creates networking infrastructure:
- VPC with DNS support
- 2 Public Subnets (for ALB & NAT)
- 2 Private Subnets (for Fargate tasks)
- Internet Gateway
- NAT Gateway
- Route Tables

#### App Service Module
Creates application infrastructure:
- ECS Cluster
- ECS Task Definition (Fargate)
- ECS Service
- Application Load Balancer
- ALB Target Group & Listener
- Security Groups
- IAM Roles (Task Execution & Task Role)

---

##  Deployment Guide

### Deployment Flow

| Step | Initiator | Action | Description |
|------|-----------|--------|-------------|
| 1 | Developer | `docker push` | Push container image to Docker Hub |
| 2 | Terraform | `terraform apply` | Provision VPC, ALB, and ECS resources |
| 3 | ECS Scheduler | API Call | Launch Fargate task in private subnet |
| 4 | Fargate | `docker pull` | Pull image via NAT Gateway |
| 5 | Fargate | `exec gunicorn` | Start application on port 8080 |
| 6 | ALB | Health Check | Verify task responds with 200 OK |
| 7 | ALB | Forward Traffic | Route public traffic (80) → container (8080) |

---

##  Usage & Commands

All Terraform commands should be run from the `terraform/` directory.

### 1. Initialize Terraform

Downloads required providers and modules:

```bash
cd terraform
terraform init
```

### 2. Plan the Deployment

Preview resources to be created:

```bash
terraform plan
```

### 3. Deploy Infrastructure

Create all AWS resources:

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 4. Get the Service URL

After successful deployment (allow ~5 minutes for Fargate warmup):

```bash
terraform output service_url
```

### 5. Test the Application

```bash
curl $(terraform output -raw service_url)
```

### 6. Destroy Infrastructure

Remove all AWS resources when done:

```bash
terraform destroy
```

---

##  API Reference

### GET /

Returns the current timestamp and client IP address.

**Request:**
```bash
curl http://<alb-dns-name>/
```

**Response:**
```json
{
  "timestamp": "2025-12-08T10:30:45.123456+00:00",
  "ip": "203.0.113.50"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string | Current UTC date/time (ISO 8601 format) |
| `ip` | string | Client's IP address (supports X-Forwarded-For) |

---

##  Security

### Application Security
-  Container runs as non-root user (`appuser`)
-  Minimal base image (`python:3.12-slim`)
-  No secrets or API keys in the image

### Infrastructure Security
-  Fargate tasks run in **private subnets** (no direct internet access)
-  Only ALB is exposed to the internet
-  Security groups restrict traffic flow
-  NAT Gateway for controlled outbound access
-  IAM roles follow least-privilege principle



---


##  Local Development

### Without Docker

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run development server
python -m flask run --host=0.0.0.0 --port=8080

# Or with Gunicorn
gunicorn -b 0.0.0.0:8080 app:app
```




