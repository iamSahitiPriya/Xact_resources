terraform {
  required_version = ">= 0.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }

  backend "s3" {
    bucket         = "xact-infra-remote-state-prod"
    key = "ecs/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "remote_state" {
  source                  = "../../"
}

resource "aws_security_group" "alb-sg-prod" {
  name        = "alb_sg-prod"
  description = "Allow ALB Traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow from Personal CIDR block"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.cidr_block]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ALB  SG"
  }
}
resource "aws_security_group" "ecs_sg-prod" {
  name        = "ecs_prod_sg"
  description = "Allow ECS Traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow from Personal CIDR block"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    security_groups      =  [aws_security_group.alb-sg-prod.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ECS  SG"
  }
}



resource "aws_ecs_cluster" "xact-backend-cluster-prod" {
  name = "xact-backend-cluster-prod"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_service" "xact-service-prod" {
  name            = "xact-service-prod"
  cluster         = aws_ecs_cluster.xact-backend-cluster-prod.id
  launch_type = "FARGATE"
  task_definition = aws_ecs_task_definition.xact-task-def-prod.arn
  desired_count   = 1
  network_configuration {
    subnets = ["subnet-042b76f3f4aa643c9","subnet-02249a393eb372da6","subnet-0184ccf3faa75628d"]
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_sg-prod.id]

  }
  load_balancer {
    target_group_arn = aws_lb_target_group.xact-backend-tg-prod.arn
    container_name   = "xact-task-def-prod"
    container_port   = 8080
  }
}

resource "aws_ecs_task_definition" "xact-task-def-prod" {
  family = "xact-task-def-prod"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  task_role_arn = aws_iam_role.xact-backend-role-ecs.arn
  execution_role_arn  = aws_iam_role.xact-backend-role-ecs.arn
  container_definitions = jsonencode([
    {
      name      = "xact-task-def-prod"
      image     = "730911736748.dkr.ecr.ap-south-1.amazonaws.com/xact-prod:latest"
      cpu       = 1024
      memory    = 2048
      essential = true
      environment: [
        {name: "MICRONAUT_ENVIRONMENTS", value: var.environment}
      ],
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      logConfiguration: {
        logDriver: "awslogs",
        options: {
          awslogs-group: "/fargate/service/xact-${var.environment}",
          awslogs-region: var.aws_region
          awslogs-stream-prefix: "ecs"
        }
      }
      secrets: [{
        name: "DB_USER",
        valueFrom: "arn:aws:secretsmanager:${var.aws_region}:${var.account}:secret:${var.DB_USER}::"
        },
        {
          name: "DB_PWD",
          valueFrom: "arn:aws:secretsmanager:${var.aws_region}:${var.account}:secret:${var.DB_PWD}::"
        },
        {
          name: "OIDC_ISSUER",
          valueFrom: "arn:aws:secretsmanager:${var.aws_region}:${var.account}:secret:${var.OIDC_ISSUER}::"
        },
        {
          name: "AUTH_USERNAME",
          valueFrom: "arn:aws:secretsmanager:${var.aws_region}:${var.account}:secret:${var.AUTH_USERNAME}::"
        },
        {
          name: "AUTH_PASSWORD",
          valueFrom: "arn:aws:secretsmanager:${var.aws_region}:${var.account}:secret:${var.AUTH_PASSWORD}::"
        }
      ]
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_lb_target_group" "xact-backend-tg-prod" {
  target_type = "ip"
  name     = "xact-backend-tg-prod"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check  {
    path = "/health"
    port = "8080"
  }
}

resource "aws_lb" "xact-backend-alb-prod" {
  name               = "xact-backend-alb-prod"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg-prod.id]
  subnets            = ["subnet-042b76f3f4aa643c9","subnet-02249a393eb372da6","subnet-0184ccf3faa75628d"]

  enable_deletion_protection = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.xact-backend-alb-prod.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:ap-south-1:730911736748:certificate/e5a4aa42-fd42-4977-a2d1-73d63bcffe45"


  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.xact-backend-tg-prod.arn
  }
}

resource "aws_iam_role" "xact-backend-role-ecs" {
  name = "xact-ecsTaskExecutionRole-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = ["ecs-tasks.amazonaws.com","ssm.amazonaws.com","kms.amazonaws.com"]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "xact-service-ecr-role" {
  role = "${aws_iam_role.xact-backend-role-ecs.name}"
  policy_arn = "arn:aws:iam::${var.account}:policy/ecsSecretManagerPolicy"
}

