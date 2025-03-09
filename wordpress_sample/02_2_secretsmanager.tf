resource "aws_secretsmanager_secret" "wordpress_mysqldb_user" {
  name = "wordpress_mysqldb_user"
}
resource "aws_secretsmanager_secret_version" "wordpress_mysqldb_user" {
  secret_id     = aws_secretsmanager_secret.wordpress_mysqldb_user.id
  secret_string = var.mysqldb_user
}

resource "aws_secretsmanager_secret" "wordpress_mysqldb_pass" {
  name = "wordpress_mysqldb_pass"
}
resource "aws_secretsmanager_secret_version" "wordpress_mysqldb_pass" {
  secret_id     = aws_secretsmanager_secret.wordpress_mysqldb_pass.id
  secret_string = var.mysqldb_pass
}