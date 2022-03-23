variable "environment" {
  description = "The name of the environment"
}

variable "aws_ecr_repository_name" {
  default     = "test-quickbutik_php"
  description = "ECR repo name"
}

variable "image_scanning_configuration" {
  default     = true
  description = "ECR IMAGE scanning feature"
}

variable "encryption_configuration" {
  default     = "AES256"
  description = "Encryption method"
}