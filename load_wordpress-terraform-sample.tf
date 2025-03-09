variable mysqldb_user {
  sensitive = true
}
variable mysqldb_pass {
  sensitive = true
}

module "wordpress_sample" {
  source  = "./wordpress_sample"
  
  environment = "staging"
  region = "eu-west-1"
  mysqldb_name = "wordpress"
  mysqldb_user = var.mysqldb_user
  mysqldb_pass = var.mysqldb_pass
}