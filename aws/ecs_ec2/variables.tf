variable "vpc_id" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
}

variable "region" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
}

variable "ecs_subnet_id" {
  description = "Value of Subnet-id"
  type        = list(any)
}

variable "appsmith_image" {
  description = "Docker image of Appsmith"
  type        = string
}

variable "ecs_instance_type" {
  description = "Instance Type"
  type        = string
}

variable "appsmith_encryption_salt" {
  description = "Encryption Salt"
  type        = string
  default     = "xGkMZcJRCB3zS"
}

variable "appsmith_encryption_password" {
  description = "Encryption Password"
  type        = string
  default     = "La01QBbbtFgQa"
}
