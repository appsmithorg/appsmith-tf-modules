resource "aws_ecs_cluster" "main" {
  name = "appsmith-fargate-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    Name = "appsmith"
  }
}

data "aws_iam_policy_document" "ssm_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
    "ssmmessages:OpenDataChannel"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ssm_policy" {
  name_prefix = "ssm-policy"
  description = "Policy to exec into fargate containers"
  policy      = data.aws_iam_policy_document.ssm_policy_doc.json
}

resource "aws_iam_role" "ecs_exec_role" {
  name_prefix = "appsmith-ecs-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_role_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "role-policy-attach" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_secret_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

### ecs fargate sg
resource "aws_security_group" "ecs_sg" {
  name        = "appsmith-security-group"
  vpc_id      = var.vpc_id
  description = "Security groups rules to apply"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 2049
    to_port     = 2049
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "appsmith"
  }
}


### CloudWatch
resource "aws_cloudwatch_log_group" "ecs_cloudwatch_log_group" {
  name              = "/appsmith-ecs-fargate/demo"
  retention_in_days = 14
}

### EFS
resource "aws_efs_file_system" "efs" {
  creation_token   = "appsmith-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"
  tags = {
    Name = "appsmith"
  }
}

## mount target
resource "aws_efs_mount_target" "efs-mount-targets" {
  count           = var.ecs_subnet_count
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = var.ecs_subnet_id[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}


resource "aws_security_group" "efs_sg" {
  name        = "appsmith-efs-security-group"
  vpc_id      = var.vpc_id
  description = "Security groups rules for EFS"

  ingress {
    protocol    = "tcp"
    from_port   = 2049
    to_port     = 2049
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "appsmith"
  }

}

## ECS service

resource "aws_ecs_service" "appsmith_ecs_service" {
  name            = "appsmith"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets         = var.ecs_subnet_id
    security_groups = [aws_security_group.ecs_sg.id, aws_security_group.efs_sg.id]
    assign_public_ip = true
  }  
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "appsmith-task-definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.ecs_exec_role.arn
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  cpu                      = 2048
  memory                   = 4096
  tags                     = { Name = "appsmith" }
  volume {
    name = "appsmith-efs"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs.id
      root_directory = "/"
    }
  }
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([{
    name      = "appsmith-task-definition",
    image     = var.appsmith_image
    essential = true
    portMappings = [
      { containerPort = 80, hostPort = 80 },
      { containerPort = 443, hostPort = 443 }
    ]
    healthCheck = {
      command = [
        "CMD-SHELL",
        "curl http://localhost/api/v1/health || exit 1"
      ]
    }
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-region"        = var.region,
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_cloudwatch_log_group.name,
        "awslogs-stream-prefix" = "appsmith"
      }
    }
    mountPoints = [{ sourceVolume = "appsmith-efs", containerPath = "/appsmith-stacks", "readOnly" = false }]
    environment = [
      { name = "APPSMITH_ENCRYPTION_PASSWORD", value = var.appsmith_encryption_password },
      { name = "APPSMITH_ENCRYPTION_SALT", value = var.appsmith_encryption_salt },
      { name = "APPSMITH_ENABLE_EMBEDDED_DB", value = "0" },
      { name = "APPSMITH_DB_URL", value = var.appsmith_db_url }
    ]
  }])
}
