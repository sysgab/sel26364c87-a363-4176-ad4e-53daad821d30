resource "aws_rds_cluster" "wordpress" {
  cluster_identifier = "wordpress"
  engine             = "aurora-mysql"
  engine_mode        = "provisioned"
  engine_version     = "8.0.mysql_aurora.3.08.1"
  database_name      = var.mysqldb_name
  master_username    = var.mysqldb_user
  master_password    = var.mysqldb_pass
  storage_encrypted  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.wordpress.name

  apply_immediately   = var.environment == "staging" ? true : false
  skip_final_snapshot = var.environment == "staging" ? true : false

  serverlessv2_scaling_configuration {
    max_capacity             = 1.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 300
  }
}

resource "aws_rds_cluster_instance" "wordpress" {
  cluster_identifier = aws_rds_cluster.wordpress.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.wordpress.engine
  engine_version     = aws_rds_cluster.wordpress.engine_version
}

resource "aws_db_subnet_group" "wordpress" {
  name       = "wordpress"
  subnet_ids = local.backend_subnets
}