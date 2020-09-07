locals {
  default_tags = {
    project = var.project
  }
  project = lower(trimspace(join("-", split(" ", var.project))))
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "JANK"
}
