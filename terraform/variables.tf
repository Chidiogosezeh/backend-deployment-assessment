variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.5/32"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair used for SSH"
  type        = string
  default     = "startuptech-key"
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "backend_instance_type" {
  description = "Instance type for the backend server"
  type        = string
  default     = "t3.micro"
}

variable "mongodb_instance_type" {
  description = "Instance type for the MongoDB server"
  type        = string
  default     = "t3.micro"
}