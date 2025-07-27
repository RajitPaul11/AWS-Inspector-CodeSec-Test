provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-123456789"
  acl    = "public-read-write"
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS instance"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "my_db" {
  identifier        = "my-db-instance"
  engine            = "mysql"
  instance_class    = "db.t2.micro"
  allocated_storage = 20
  username          = "admin"
  password          = "admin123"
  db_name           = "mydatabase"
  port              = 3306
  multi_az          = false
  publicly_accessible = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

# IAM Role with excessive permissions
resource "aws_iam_role" "insecure_role" {
  name = "insecure-iam-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

resource "aws_iam_policy" "overly_permissive_policy" {
  name        = "overly-permissive-policy"
  description = "Policy that grants excessive permissions"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  role       = aws_iam_role.insecure_role.name
  policy_arn = aws_iam_policy.overly_permissive_policy.arn
}

# Exposing sensitive data in environment variables
resource "aws_ecs_task_definition" "example_task" {
  family                   = "example-task"
  network_mode             = "awsvpc"
  container_definitions    = jsonencode([{
    name      = "example-container"
    image     = "nginx"
    essential = true
    environment = [
      {
        name  = "DB_PASSWORD"
        value = "password123"  # Exposing sensitive data in environment variable
      }
    ]
  }])
}

resource "aws_lambda_function" "insecure_lambda" {
  function_name = "insecureLambda"
  role          = aws_iam_role.insecure_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  environment {
    variables = {
      DB_PASSWORD = "password123"  # Exposing sensitive data in environment variable
    }
  }
  # Vulnerability: Code is directly in-line with no encryption.
  code {
    zip_file = "exports.handler = function(event, context, callback) { callback(null, 'Hello World'); };"
  }
}
