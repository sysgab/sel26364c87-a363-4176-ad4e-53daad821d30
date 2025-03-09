resource "aws_cloudwatch_log_group" "wordpress_fargate_logs" {
  name              = "wordpress-${var.environment}"
  retention_in_days = var.cwlogs_retention_days
}