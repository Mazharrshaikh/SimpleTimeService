# ----------------------------------------
# 1. ALB Security Group (Allows traffic from Internet on Port 80)
# ----------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP/80 from internet"
  vpc_id      = var.vpc_id

  # Ingress: Allow HTTP (80) from anywhere
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Allow all outbound traffic
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------------------------
# 2. Application Security Group (Allows traffic from ALB on container port)
# ----------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Allow inbound traffic from ALB to Fargate tasks"
  vpc_id      = var.vpc_id

  # Ingress: Allow traffic on container_port only from the ALB's security group
  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.alb_sg.id]
  }
  
  # Egress: Allow all outbound traffic (needed for image pull via NAT Gateway)
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}