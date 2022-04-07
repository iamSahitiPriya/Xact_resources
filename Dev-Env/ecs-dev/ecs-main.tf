terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "alb-sg" {
  name        = "alb_sg"
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
resource "aws_security_group" "ecs_sg" {
  name        = "ecs_dev_sg"
  description = "Allow ECS Traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow from Personal CIDR block"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    security_groups      =  [aws_security_group.alb-sg.id]
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



resource "aws_ecs_cluster" "xact-backend-cluster" {
  name = "xact-backend-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_service" "xact-service" {
  name            = "xact-service"
  cluster         = aws_ecs_cluster.xact-backend-cluster.id
  launch_type = "FARGATE"
  task_definition = aws_ecs_task_definition.xact-task-def.arn
  desired_count   = 1
  network_configuration {
    subnets = ["subnet-042b76f3f4aa643c9","subnet-02249a393eb372da6","subnet-0184ccf3faa75628d"]
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_sg.id]

  }
  load_balancer {
    target_group_arn = aws_lb_target_group.xact-backend-tg.arn
    container_name   = "xact-task-def"
    container_port   = 8080
  }
}

resource "aws_ecs_task_definition" "xact-task-def" {
  family = "xact-task-def"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  task_role_arn = aws_iam_role.xact-backend-role-ecs.arn
  execution_role_arn  = aws_iam_role.xact-backend-role-ecs.arn
  container_definitions = jsonencode([
    {
      name      = "xact-task-def"
      image     = "730911736748.dkr.ecr.ap-south-1.amazonaws.com/xact:latest"
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
        }
      ]
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_lb_target_group" "xact-backend-tg" {
  target_type = "ip"
  name     = "xact-backend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check  {
    path = "/health"
    port = "8080"
  }
}

resource "aws_lb" "xact-backend-alb" {
  name               = "xact-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = ["subnet-042b76f3f4aa643c9","subnet-02249a393eb372da6","subnet-0184ccf3faa75628d"]

  enable_deletion_protection = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.xact-backend-alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:ap-south-1:730911736748:certificate/4b530396-acfa-40b2-8e05-f5def63db12d"


  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.xact-backend-tg.arn
  }
}

resource "aws_iam_role" "xact-backend-role-ecs" {
  name = "xact-ecsTaskExecutionRole"

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

