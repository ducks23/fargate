# ecs.tf

resource "aws_ecs_cluster" "app" {
  name = "app"
}

resource "aws_ecs_service" "django_api" {
  name            = "django-api"
  task_definition = aws_ecs_task_definition.django_api.arn
  cluster         = aws_ecs_cluster.app.id
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.django_api.arn
    container_name   = "django-api"
    container_port   = "8000"
  }

  network_configuration {
    assign_public_ip = false

    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_api.id,
    ]

    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
    ]
  }
}

resource "aws_cloudwatch_log_group" "django_api" {
  name = "/ecs/django-api"
}



resource "aws_ecs_task_definition" "django_api" {
  family             = "django-api"
  execution_role_arn = aws_iam_role.django_api_task_execution_role.arn


  container_definitions = <<EOF
  [
    {
      "name": "django-api",
      "image": "public.ecr.aws/t1r6r0z7/django_api:latest",
      "portMappings": [
        {
          "containerPort": 8000
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "us-west-2",
          "awslogs-group": "/ecs/django-api",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  EOF

  cpu                      = 1024
  memory                   = 2048
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
}

resource "aws_iam_role" "django_api_task_execution_role" {
  name               = "django-api-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecs_task_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.django_api_task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}


resource "aws_lb_target_group" "django_api" {
  name        = "django-api"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.app_vpc.id

  health_check {
    enabled = true
    path    = "/health"
  }

  depends_on = [aws_alb.django_api]
}

resource "aws_alb" "django_api" {
  name               = "django-api-lb"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]

  security_groups = [
    aws_security_group.http.id,
    aws_security_group.https.id,
    aws_security_group.egress_all.id,
  ]

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_alb_listener" "django_api_http" {
  load_balancer_arn = aws_alb.django_api.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.django_api.arn
  }
}

output "alb_url" {
  value = "http://${aws_alb.django_api.dns_name}"
}
