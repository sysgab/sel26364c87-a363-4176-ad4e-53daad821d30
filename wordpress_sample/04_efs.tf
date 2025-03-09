# Create a security group
resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Allow NFS traffic from ecs_wordpress_sg"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "efs_ingress_from_ecsfargate" {
  security_group_id        = aws_security_group.efs_sg.id
  type                     = "ingress"
  description              = "Ingress from ECS Fargate"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_wordpress_sg.id
}

resource "aws_efs_file_system" "wordpress_efs" {
  creation_token = "efs-wordpress"
  performance_mode = "generalPurpose"
  throughput_mode = "elastic"
  encrypted = true
}

resource "aws_efs_mount_target" "mount_target" {
  count           = length(local.backend_subnets)
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = local.backend_subnets[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_backup_policy" "wordpress_efs_backup_policy" {
  file_system_id = aws_efs_file_system.wordpress_efs.id

  backup_policy {
    status = var.environment == "staging" ? "DISABLED" : "ENABLED"
  }
}