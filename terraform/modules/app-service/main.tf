# ----------------------------------------
# 1. CloudWatch Log Group
# ----------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# ----------------------------------------
# 2. ECS Cluster
# ----------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# ----------------------------------------
# 3. Application Load Balancer (ALB)
# ----------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets # ALB is public-facing
}

# ----------------------------------------
# 4. Target Group (TG)
# ----------------------------------------
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

# ----------------------------------------
# 5. ALB Listener
# ----------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ----------------------------------------
# 6. ECS Task Definition (The Blueprint)
# ----------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn # Reusing execution role for simplicity

  container_definitions = jsonencode([
    {
      name      = var.project_name
      image     = var.container_image
      cpu       = var.fargate_cpu
      memory    = var.fargate_memory
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ----------------------------------------
# 7. ECS Service (The Orchestrator)
# ----------------------------------------
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  
  # VPC, Subnet, and Security Group configuration for Fargate
  network_configuration {
    security_groups  = [aws_security_group.app_sg.id]
    subnets          = var.private_subnets # Tasks run in private subnets
    assign_public_ip = false
  }

  # Link service to the ALB
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.project_name
    container_port   = var.container_port
  }

  force_new_deployment = true
}

# ----------------------------------------
# 8. Data Source for CloudWatch Logs region
# ----------------------------------------
data "aws_region" "current" {}