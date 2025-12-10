variable "project_name" {
  description = "A unique name for the project."
  type        = string
}

variable "region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "container_image" {
  description = "The Docker image URI for the application (e.g., username/repo:tag)."
  type        = string
}

variable "app_port" {
  description = "The port the containerized application is listening on."
  type        = number
  default     = 8080
}