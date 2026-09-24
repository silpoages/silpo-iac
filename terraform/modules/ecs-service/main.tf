locals {
  tags = merge(var.tags, {
    Module = "ecs-service"
  })

  serve_https = var.certificate_arn != null

  api_base_url = coalesce(
    var.api_base_url_override,
    "${local.serve_https ? "https" : "http"}://${aws_lb.this.dns_name}",
  )

  container_environment = concat(
    var.environment_variables,
    [{ name = "API_BASE_URL", value = local.api_base_url }],
  )
}

data "aws_region" "current" {}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# App-level secrets this module owns directly (as opposed to var.secrets, which the caller
# wires in from elsewhere, e.g. the database credentials from the rds-postgres module).
resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "${var.name}/jwt-secret-key"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

resource "aws_secretsmanager_secret" "resend_api_key" {
  name = "${var.name}/resend-api-key"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "resend_api_key" {
  secret_id     = aws_secretsmanager_secret.resend_api_key.id
  secret_string = "CHANGE_ME"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

locals {
  internal_secret_arns = [
    aws_secretsmanager_secret.jwt_secret.arn,
    aws_secretsmanager_secret.resend_api_key.arn,
  ]

  all_secret_arns = concat(local.internal_secret_arns, var.secret_arns)

  all_secrets = concat(
    [
      { name = "JWT_SECRET_KEY", value_from = aws_secretsmanager_secret.jwt_secret.arn },
      { name = "RESEND_API_KEY", value_from = aws_secretsmanager_secret.resend_api_key.arn },
    ],
    var.secrets,
  )
}

data "aws_iam_policy_document" "secrets_access" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "ssm:GetParameters"]
    resources = local.all_secret_arns
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${var.name}-secrets-access"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.secrets_access.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = local.tags
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Allows inbound HTTP/HTTPS from the internet to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = local.serve_https ? [443] : []
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.name}-alb-sg"
  })
}

resource "aws_security_group" "service" {
  name        = "${var.name}-service-sg"
  description = "Allows inbound traffic from the ALB to the ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.name}-service-sg"
  })
}

resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  tags = local.tags
}

resource "aws_lb_target_group" "this" {
  name        = var.name
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.serve_https ? [1] : []
    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.serve_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.serve_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = local.container_environment
      secrets = [
        for s in local.all_secrets : { name = s.name, valueFrom = s.value_from }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.task_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.name
    container_port   = var.container_port
  }

  tags = local.tags

  depends_on = [aws_lb_listener.http]
}
