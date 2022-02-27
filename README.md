# Web-Setup
Terraform AWS module for creating a website environment with load balancing, auto-scaling groups, and DNS records

Usage:
Check variables.tf to find variables necessary for usage.

```
module "web-setup" {
    source = "https://github.com/sirrico/Web-Setup"
    vpc_id = aws_vpc.main_vpc.id
    server_name = "Website"
    prefix = "ws"
    external = true
    domain = "example.com"
    key_name = "main"
    user_data = "init.sh"
    max_size = 2
}
```