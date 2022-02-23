variable "vpc_id" {
    type = string
    description = "VPC ID"
}

variable "cidr_block_primary" {
    type = string
    description = "Subnet CIDR block for 1st AZ"
    default = "10.0.1.0/24"
}

variable "cidr_block_secondary" {
    type = string
    description = "Subnet CIDR block for 2nd AZ"
    default = "10.0.2.0/24"
}

variable "server_name" {
    type = string
    description = "Name of the webserver"
}

variable "ami" {
    type = string
    description = "AMI to use for webserver"
    default = "ami-08e4e35cccc6189f4"
}

variable "instance_type" {
    type = string
    description = "Type of instance"
    default = "t2.micro"
}

variable "iam_instance_profile" {
    type = string
    description = "Which IAM for webserver"
    default = "ec2_role"
}

variable "key_name" {
    type = string
    description = "Name of security key"
}

variable "user_data" {
    type = string
    description = "Path to file for startup user_data"
}

variable "max_size" {
    type = number
    description = "Maximum number of instances to scale to"
    default = 1
}

variable "domain" {
    type = string
    description = "Website domain address"
    default = "example.com"
}

variable "external" {
    type = bool
    description = "Whether website is assigned DNS records via R53"
}

variable "prefix" {
    type = string
    description = "Two letter prefix to use on created AWS service names"

}