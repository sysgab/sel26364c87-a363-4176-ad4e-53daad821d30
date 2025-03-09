# Create a security group
resource "aws_security_group" "ecs_wordpress_sg" {
  name        = "ecs-frontend-sg"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  security_group_id = aws_security_group.ecs_wordpress_sg.id
  description       = "Ingress from ALB"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "ecs_egress_https" {
  security_group_id = aws_security_group.ecs_wordpress_sg.id
  description       = "Egress to Any"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ecs_egress_mysql" {
  security_group_id = aws_security_group.ecs_wordpress_sg.id
  description       = "Egress Mysql"
  type              = "egress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  source_security_group_id = aws_security_group.rds_sg.id
}

resource "aws_security_group_rule" "ecs_egress_efs" {
  security_group_id = aws_security_group.ecs_wordpress_sg.id
  description       = "Egress NFS"
  type              = "egress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  source_security_group_id = aws_security_group.efs_sg.id
}


resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster-${var.environment}"   
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_ecs_service" "main" {
  name                               = "wordpress-service-${var.environment}"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.wordpress_task.arn
  desired_count                      = 2
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 150
  scheduling_strategy                = "REPLICA"
  availability_zone_rebalancing      = "ENABLED"

  network_configuration {
    security_groups  = [aws_security_group.ecs_wordpress_sg.id]
    subnets          = local.backend_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

# execution role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "wordpress-ecsTaskExecutionRole"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}
 
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_fargate_wordpress_policy" {
  name        = "wordpress_custom_policy"
  description = "custom policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = [
          aws_secretsmanager_secret_version.wordpress_mysqldb_user.arn,
          aws_secretsmanager_secret_version.wordpress_mysqldb_pass.arn
        ]
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-custom-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_fargate_wordpress_policy.arn
}


resource "aws_ecs_task_definition" "wordpress_task" {
  family                   = "wordpress-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = "wpdata"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.wordpress_efs.id
      transit_encryption      = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = "wordpress:${var.wordpress_ver}"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      environment = [
        {
          name  = "WORDPRESS_DB_HOST"
          value = aws_rds_cluster.wordpress.endpoint
        },
        {
          name  = "WORDPRESS_DB_NAME"
          value = var.mysqldb_name
        }
      ]
      secrets = [
        {
          name  = "WORDPRESS_DB_USER"
          valueFrom = aws_secretsmanager_secret_version.wordpress_mysqldb_user.arn
        },
        {
          name  = "WORDPRESS_DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret_version.wordpress_mysqldb_pass.arn
        }
      ]
      mountPoints = [
        {
          sourceVolume = "wpdata"
          containerPath = "/var/www/html"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = aws_cloudwatch_log_group.wordpress_fargate_logs.name
          awslogs-region = var.region
          awslogs-stream-prefix = "ecs_wordpress"
        }
      }
    }
  ])
}

# autoscaling fargate
resource "aws_appautoscaling_target" "ecs_target" {
  min_capacity       = 1
  max_capacity       = 3
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "ecs-scale-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 50.0
  }
}