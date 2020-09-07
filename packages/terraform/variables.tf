locals {
  project = lower(trimspace(join("-", split(" ", var.project))))

  default_tags = {
    project = var.project
  }
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "JANK"
}

variable "ecs_capacity" {
  type        = number
  description = "Target number of instances to use for ECS"
  default     = 2
}