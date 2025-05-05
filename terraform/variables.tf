variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project, used as prefix for resources"
  type        = string
  default     = "realtime-datalake"
}

variable "redshift_database" {
  description = "Name of the Redshift database"
  type        = string
  default     = "datalake"
}

variable "redshift_table" {
  description = "Name of the main table in Redshift"
  type        = string
  default     = "transformed_data"
}

variable "redshift_username" {
  description = "Master username for Redshift cluster"
  type        = string
  default     = "admin"
}

variable "redshift_password" {
  description = "Master password for Redshift cluster"
  type        = string
  sensitive   = true
} 