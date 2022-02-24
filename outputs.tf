output "server_subnet_primary" {
    value = aws_subnet.server_subnet_primary
}

output "server_subnet_secondary" {
    value = aws_subnet.server_subnet_secondary
}

output "allow_web" {
    value = aws_security_group.allow_web
}


output "web_setup_as_group" {
    value = aws_autoscaling_group.web_setup_as_group
}

output "web_setup_lb" {
    value = aws_lb.web_setup_lb
}

output "web_setup_as_policy" {
    value = aws_autoscaling_policy.web_setup_as_policy
}

output "web_setup_scaledown" {
    value = aws_autoscaling_policy.web_setup_scaledown
}

output "web_setup_scaling_alarm" {
    value = aws_cloudwatch_metric_alarm.web_setup_scaling_alarm
}

output "web_setup_tg" {
    value = aws_alb_target_group.web_setup_tg
}

output "web_setup_alb_listener" {
    value = aws_alb_listener.web_setup_alb_listener
}

output "web_setup_as_attach" {
    value = aws_autoscaling_attachment.web_setup_as_attach
}