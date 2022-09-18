module "awsvpc" {
  source = "/var/terraform/modules/vpc/"           #here I've created VPC as a module and provided the location as source.

  project_name = var.project_name
  project_env = var.project_env
  vpc_cidr = var.cidr_block
  region = var.region
}

resource "aws_security_group" "sg" {

  name_prefix = "freedom-"
  description = "allow http, https, ssh"
  vpc_id      = module.awsvpc.myvpc

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

    ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  tags = {
    Name = "${var.project_name}-sg",
    project = var.project_name,
    env = var.project_env
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.awsvpc.myvpc
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay = 60
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/health.html"
    protocol            = "HTTP"
    matcher             = 200
    
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = [ module.awsvpc.public1, module.awsvpc.public2 ]
  enable_deletion_protection = false
  depends_on = [ aws_lb_target_group.tg ]
  tags = {
     Name = "${var.project_name}-alb"
   }
}

output "alb-endpoint" {
  value = aws_lb.alb.dns_name
} 


resource "aws_lb_listener" "listener1" {
  load_balancer_arn = aws_lb.alb.id
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


resource "aws_lb_listener" "listener2" {

  load_balancer_arn = aws_lb.alb.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "No Page Found"
      status_code  = "200"
    }
  }
   depends_on = [  aws_lb.alb ]
}

resource "aws_lb_listener_rule" "rule" {

  listener_arn = aws_lb_listener.listener2.id
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  condition {
    host_header {
      values = [var.domain_name]
    }
  }
}

    
#A key pair should be created as "key"
    
resource "aws_key_pair" "mykey" {
  key_name   = "${var.project_name}-${var.project_env}"
  public_key = file("key.pub")                                     
  tags = {
    Name = "${var.project_name}-${var.project_env}",
    project = var.project_name
    env = var.project_env
  }
}

resource "aws_launch_configuration" "lc" {
  name_prefix   = "${var.project_name}-${var.project_env}-lc-"
  image_id          = var.ami_id
  instance_type     = var.instance_type
  key_name          = aws_key_pair.mykey.id
  security_groups   = [ aws_security_group.sg.id ]
  user_data         = file("user-data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {

  name_prefix = "${var.project_name}-${var.project_env}-asg-"
  default_instance_warmup = 120
  vpc_zone_identifier = [ module.awsvpc.public1, module.awsvpc.public2 ]     #to select the subnet on which asg have to be created
  desired_capacity = 2
  max_size = 2
  min_size = 2
  force_delete = true
  health_check_type = "EC2"
  target_group_arns = [ aws_lb_target_group.tg.arn ]
  launch_configuration    = aws_launch_configuration.lc.id

  tag {
    key = "Name"
    value = "${var.project_name}-${var.project_env}"
    propagate_at_launch = true
  }

  tag {
    key = "project"
    value = "${var.project_name}"
    propagate_at_launch = true
  }

  tag {
    key = "env"
    value = "${var.project_env}"
    propagate_at_launch = true
  }


  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "record" {                     
  zone_id = var.hosted_zone
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}
