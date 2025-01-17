## Ecs-node Related
data "aws_iam_policy_document" "ecs_node_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_node_role" {
  name_prefix        = "appsmith-ecs-node-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_node_doc.json
}


resource "aws_iam_role_policy_attachment" "ecs_node_container_service_policy" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_node_container_policy" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_node_ebs_driver_policy" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_instance_profile" "ecs_node" {
  name_prefix = "appsmith-ecs-node-profile"
  path        = "/ecs/instance/"
  role        = aws_iam_role.ecs_node_role.name
}

## Cluster Related
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "key_pair" {
  key_name   = "appsmith-key-pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}

# Save the private key locally
output "private_key_pem" {
  value     = tls_private_key.key_pair.private_key_pem
  sensitive = true
}

resource "local_file" "private_key" {
  filename        = "${path.module}/appsmith-key-pair.pem"
  content         = tls_private_key.key_pair.private_key_pem
  file_permission = "0600"
}

resource "aws_ecs_cluster" "main" {
  name = "appsmith-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    Name = "appsmith"
  }
}

resource "aws_security_group" "ecs_node_sg" {
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
    from_port   = 22
    to_port     = 22
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

data "aws_ssm_parameter" "ecs_node_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs_ec2" {
  name_prefix            = "appsmith-"
  image_id               = data.aws_ssm_parameter.ecs_node_ami.value
  instance_type          = var.ecs_instance_type
  vpc_security_group_ids = [aws_security_group.ecs_node_sg.id]
  iam_instance_profile { arn = aws_iam_instance_profile.ecs_node.arn }
  key_name               = aws_key_pair.key_pair.key_name
  monitoring { enabled = true }
  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config;
    EOF
  )
}

resource "aws_autoscaling_group" "ecs" {
  name_prefix               = "appsmith-ecs-asg-"
  vpc_zone_identifier       = var.ecs_subnet_id
  min_size                  = 1
  max_size                  = 2
  health_check_grace_period = 0
  health_check_type         = "EC2"

  launch_template {
    id      = aws_launch_template.ecs_ec2.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "appsmith-ecs-cluster"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}


resource "aws_ecs_capacity_provider" "main" {
  name = "appsmith-ecs-ec2-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    base              = 1
    weight            = 100
  }
}


## Task Related

data "aws_iam_policy_document" "ecs_task_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_exec_role" {
  name_prefix        = "appsmith-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_role_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_secret_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/appsmith-ecs/demo"
  retention_in_days = 14
}


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

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "appsmith-task-definition"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.ecs_exec_role.arn
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  cpu                      = 1024
  memory                   = 3072
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
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name,
        "awslogs-stream-prefix" = "appsmith"
      }
    }
    mountPoints = [{ sourceVolume = "appsmith-efs", containerPath = "/appsmith-stacks", "readOnly" = false }]
    environment = [
      { name = "APPSMITH_ENCRYPTION_PASSWORD", value = var.appsmith_encryption_password },
      { name = "APPSMITH_ENCRYPTION_SALT", value = var.appsmith_encryption_salt },
      { name = "APPSMITH_ENABLE_EMBEDDED_DB", value = "0" },
      { name = "APPSMITH_DB_URL", value = var.appsmith_db_url },
      { name = "APPSMITH_REDIS_URL", value = var.appsmith_redis_url }
    ]
  }])
}

## ECS service

resource "aws_ecs_service" "appsmith_ecs_service" {
  name            = "appsmith"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  launch_type     = "EC2"
  desired_count   = 1
}

