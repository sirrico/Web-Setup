terraform {
    required_version = ">=0.12"
}

data "aws_availability_zones" "available_zones" {
    state = "available"
}

data "aws_ami" "amazon-linux-2" {
 most_recent = true
    owners = ["amazon"]

 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }


 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}

resource "aws_subnet" "server_subnet_primary" {
    vpc_id = var.vpc_id
    cidr_block = var.cidr_block_primary
    availability_zone = data.aws_availability_zones.available_zones.names[0]
}

resource "aws_subnet" "server_subnet_secondary" {
    vpc_id = var.vpc_id
    cidr_block = var.cidr_block_secondary
    availability_zone = data.aws_availability_zones.available_zones.names[1]
}

resource "aws_security_group" "allow_web" {
    name = "allow-web-traffic"
    description = "Allow inbound traffic on 22, 80, and 445"
    vpc_id = var.vpc_id

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "allow-web"
    }
}

resource "aws_security_group" "allow_web_elb" {
    name = "allow-web-traffic-elb"
    description = "Allow inbound traffic on 22, 80, and 445 for ELB"
    vpc_id = var.vpc_id

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "allow-web"
    }
}


resource "aws_launch_configuration" "web_setup_launch_config" {
    name_prefix = "lc-${var.prefix}-"

    image_id = "${var.ami == "" ? data.aws_ami.amazon-linux-2.id : var.ami}"
    instance_type = var.instance_type
    key_name = var.key_name
    user_data = "${file(var.user_data)}"
    security_groups = [
        aws_security_group.allow_web.id
        ]
    associate_public_ip_address = true
    iam_instance_profile = var.iam_instance_profile

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "web_setup_as_group" {
    name_prefix = "sg-${var.prefix}-"
    vpc_zone_identifier = [
        aws_subnet.server_subnet_primary.id, 
        aws_subnet.server_subnet_secondary.id
        ]
    launch_configuration = aws_launch_configuration.web_setup_launch_config.name
    min_size = 1
    max_size = var.max_size
    health_check_grace_period = 300
    health_check_type = "ELB"
    force_delete = true
    lifecycle {
        create_before_destroy = true
        ignore_changes = [
            load_balancers,
            target_group_arns
        ]
    }
    tag {
        key = "Name"
        value = var.server_name
        propagate_at_launch = "true"
    }
}

resource "aws_autoscaling_policy" "web_setup_as_policy" {
    name = "web-setup-as-policy"
    autoscaling_group_name = aws_autoscaling_group.web_setup_as_group.name
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = 1
    cooldown = 600
    policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "web_setup_scaling_alarm" {
    alarm_name = "web-setup-scaling-alarm"
    alarm_description = "Alarm once cpu usage increases"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = 2
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = 240
    statistic = "Average"
    threshold = 50

    dimensions = {
      "AutoScalingGroupName": aws_autoscaling_group.web_setup_as_group.name
    }
    actions_enabled = true
    alarm_actions = [aws_autoscaling_policy.web_setup_as_policy.arn]
}

resource "aws_autoscaling_policy" "web_setup_scaledown" {
    name = "web-setup-scaledown"
    autoscaling_group_name = aws_autoscaling_group.web_setup_as_group.name
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = -1
    cooldown = 300
    policy_type = "SimpleScaling"
}

resource "aws_lb" "web_setup_lb" {
    name_prefix = "lb-${var.prefix}-"
    internal = false
    load_balancer_type = "application"
    subnets = [
        aws_subnet.server_subnet_primary.id, 
        aws_subnet.server_subnet_secondary.id
        ]
    security_groups = [aws_security_group.allow_web_elb.id]

    enable_cross_zone_load_balancing = true

    tags = {
        Name = "web-setup-lb"
    }
}

resource "aws_alb_target_group" "web_setup_tg" {
    name_prefix = "tg-${var.prefix}-"
    port = 80
    protocol = "HTTP"
    vpc_id = var.vpc_id
    slow_start = 30

    health_check {
        healthy_threshold = 3
        unhealthy_threshold = 3
        timeout = 15
        path = "/index.html"
        interval = 60
    }
}

resource "aws_alb_listener" "web_setup_alb_listener" {
    load_balancer_arn = aws_lb.web_setup_lb.arn
    port = 80
    protocol = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = aws_alb_target_group.web_setup_tg.arn
    }
}

resource "aws_autoscaling_attachment" "web_setup_as_attach" {
    lb_target_group_arn = aws_alb_target_group.web_setup_tg.arn
    autoscaling_group_name = aws_autoscaling_group.web_setup_as_group.id
}

output "elb_dns_name" {
    value = aws_lb.web_setup_lb.dns_name
}

resource "aws_route53_zone" "web_setup_DNS_zone" {
    count = var.external ? 1 : 0
    name = var.domain

    tags = {
        Environment = "Website"
    }
}

resource "aws_route53_record" "www" {
    count = var.external ? 1 : 0
    zone_id = aws_route53_zone.web_setup_DNS_zone[0].zone_id
    name = "www.${var.domain}"
    type = "A"

    alias {
        name = aws_lb.web_setup_lb.dns_name
        zone_id = aws_lb.web_setup_lb.zone_id
        evaluate_target_health = true
    }
}

resource "aws_route53_record" "plain_domain" {
    count = var.external ? 1 : 0
    zone_id = aws_route53_zone.web_setup_DNS_zone[0].zone_id
    name = var.domain
    type = "A"

    alias {
        name = aws_lb.web_setup_lb.dns_name
        zone_id = aws_lb.web_setup_lb.zone_id
        evaluate_target_health = true
    }
}


resource "aws_route53_record" "ns" {
    count = var.external ? 1 : 0
    allow_overwrite = true
    zone_id = aws_route53_zone.web_setup_DNS_zone[0].zone_id
    name = var.domain
    type = "NS"
    ttl = 172800

    records = [
        aws_route53_zone.web_setup_DNS_zone[0].name_servers[0],
        aws_route53_zone.web_setup_DNS_zone[0].name_servers[1],
        aws_route53_zone.web_setup_DNS_zone[0].name_servers[2],
        aws_route53_zone.web_setup_DNS_zone[0].name_servers[3]
    ]
}
