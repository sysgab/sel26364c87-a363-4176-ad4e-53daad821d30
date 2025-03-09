resource "tls_private_key" "selfsigned" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_self_signed_cert" "selfsigned" {
  private_key_pem = tls_private_key.selfsigned.private_key_pem

  subject {
    common_name  = "example.com"
    organization = "ACME Examples, Inc"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "selfsigned" {
  private_key      = tls_private_key.selfsigned.private_key_pem
  certificate_body = tls_self_signed_cert.selfsigned.cert_pem
}

resource "aws_security_group" "alb_sg" {
  name        = "wordpress-alb-sg"
  description = "Regulate incoming and outgoing HTTPS/HTTP traffic"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "ingress_to_alb_http" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "Ingress HTTP to Alb"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress_to_alb_https" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "Ingress HTTPS to Alb"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress_to_ecs_fargate" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "Egress to ECS Fargate"
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  source_security_group_id = aws_security_group.ecs_wordpress_sg.id
}

# alb
resource "aws_lb" "application_load_balancer" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.frontend_subnets
}

#Defining the target group and a health check on the application
resource "aws_lb_target_group" "wordpress_tg" {
  name                      = "wordpress-tg"
  port                      = 80
  protocol                  = "HTTP"
  target_type               = "ip"
  vpc_id                    = aws_vpc.main.id
  health_check {
      path                  = "/"
      protocol              = "HTTP"
      matcher               = "200,302" # after deployment wordpress redirects to the install page
      port                  = "traffic-port"
      healthy_threshold     = 2
      unhealthy_threshold   = 2
      timeout               = 10
      interval              = 30
  }
}

# Create an HTTP listener
resource "aws_lb_listener" "listener_http" {
  load_balancer_arn = aws_lb.application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Create an HTTPS listener
resource "aws_lb_listener" "listener_https" {
  load_balancer_arn = aws_lb.application_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn  = aws_acm_certificate.selfsigned.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}