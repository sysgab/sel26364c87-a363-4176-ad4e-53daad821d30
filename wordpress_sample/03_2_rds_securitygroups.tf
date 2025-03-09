# Create a security group for rds
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow 3306 only from frontends"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "mysql_ingress_from_ecsfargate" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Ingress from ECS Fargate"
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  source_security_group_id = aws_security_group.ecs_wordpress_sg.id
}