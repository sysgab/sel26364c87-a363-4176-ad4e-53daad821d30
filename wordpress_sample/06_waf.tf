# Create a WAF web ACL
resource "aws_wafv2_web_acl" "wordpress" {
  name        = "wordpress-waf-acl"
  description = "managed acl wordpress"
  scope       = "REGIONAL"
  
  default_action {
    allow {}
  }

  rule {
    name     = "CommonRuleSet"
    priority = 0

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "WAFGeneric"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl_association" "wordpress_web_acl_alb" {
  resource_arn = aws_lb.application_load_balancer.arn
  web_acl_arn  = aws_wafv2_web_acl.wordpress.arn
}