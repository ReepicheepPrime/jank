locals {
  default_tags = {
    project = lower(trimspace(join("-", split(" ", var.project))))
  }
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "JANK"
}
