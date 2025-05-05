terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Buckets
resource "aws_s3_bucket" "raw_zone" {
  bucket = "${var.project_name}-raw-zone"
}

resource "aws_s3_bucket" "curated_zone" {
  bucket = "${var.project_name}-curated-zone"
}

# Kinesis Stream
resource "aws_kinesis_stream" "data_stream" {
  name             = "${var.project_name}-stream"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

# Lambda Function
resource "aws_lambda_function" "kinesis_processor" {
  filename         = "../lambda/kinesis_ingest.zip"
  function_name    = "${var.project_name}-kinesis-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "kinesis_ingest.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      RAW_BUCKET = aws_s3_bucket.raw_zone.bucket
    }
  }
}

# Glue Job
resource "aws_glue_job" "transform_job" {
  name     = "${var.project_name}-transform-job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    script_location = "s3://${aws_s3_bucket.raw_zone.bucket}/glue-scripts/transform_data.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language" = "python"
    "--job-bookmark-option" = "job-bookmark-enable"
    "--RAW_BUCKET" = aws_s3_bucket.raw_zone.bucket
    "--CURATED_BUCKET" = aws_s3_bucket.curated_zone.bucket
    "--REDSHIFT_DATABASE" = var.redshift_database
    "--REDSHIFT_TABLE" = var.redshift_table
  }
}

# Step Function
resource "aws_sfn_state_machine" "data_pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "Data Pipeline State Machine"
    StartAt = "ProcessKinesisData"
    States = {
      ProcessKinesisData = {
        Type = "Task"
        Resource = aws_lambda_function.kinesis_processor.arn
        Next = "TransformData"
      }
      TransformData = {
        Type = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.transform_job.name
        }
        End = true
      }
    }
  })
}

# Redshift Cluster
resource "aws_redshift_cluster" "data_warehouse" {
  cluster_identifier  = "${var.project_name}-cluster"
  database_name       = var.redshift_database
  master_username     = var.redshift_username
  master_password     = var.redshift_password
  node_type          = "dc2.large"
  cluster_type       = "single-node"
  skip_final_snapshot = true
}

# IAM Roles
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "step_function_role" {
  name = "${var.project_name}-step-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
} 