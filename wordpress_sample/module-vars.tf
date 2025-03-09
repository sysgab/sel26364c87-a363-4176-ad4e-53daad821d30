locals {
  frontend_subnets = [aws_subnet.frontend_a.id,aws_subnet.frontend_b.id,aws_subnet.frontend_c.id]
  backend_subnets = [aws_subnet.backend_a.id,aws_subnet.backend_b.id,aws_subnet.backend_c.id]
  frontend_cidr_blocks = [aws_subnet.frontend_a.cidr_block, aws_subnet.frontend_b.cidr_block, aws_subnet.frontend_c.cidr_block]
}

variable "environment" {
    default = "production"
}

variable "region" {}
variable "mysqldb_name" {}
variable "mysqldb_user" {}
variable "mysqldb_pass" {}
variable "cwlogs_retention_days" {
    default = 1
}
variable "wordpress_ver" {
    default = "latest"
}
variable "ecs_cpu" {
    default = "256"
}
variable "ecs_memory" {
    default = "512"
}