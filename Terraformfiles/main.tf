provider "aws" {
  region = "eu-north-1" # Or your desired AWS region
}

# ----------------------------------------------------
# S3 Bucket for Static Website
# ----------------------------------------------------
resource "aws_s3_bucket" "static_website_bucket" {
  bucket = "my-Amazon-static-website" # IMPORTANT: Choose a unique bucket name
  acl    = "public-read" # Allows public access for static website hosting

  tags = {
    Name        = "StaticWebsiteBucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_website_configuration" "static_website_config" {
  bucket = aws_s3_bucket.static_website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html" # Optional: You can create an error.html later
  }
}

# ----------------------------------------------------
# IAM Roles for AWS CI/CD Services
# ----------------------------------------------------

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "CodeBuildServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "CodeBuildServiceRole"
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "CodeBuildPolicy-StaticWebsite"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:ListMultipartUploads" # Needed for larger uploads
        ],
        Effect   = "Allow",
        Resource = [
          aws_s3_bucket.static_website_bucket.arn,
          "${aws_s3_bucket.static_website_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*" # Allows logging to CloudWatch
      },
      {
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutCodeCoverages",
          "codebuild:BatchPutTestCases"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketLocation"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::codepipeline-*" # For CodePipeline artifacts bucket (default managed by CodePipeline)
      }
    ]
  })
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "CodePipelineServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "CodePipelineServiceRole"
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "CodePipelinePolicy-StaticWebsite"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::codepipeline-*", # For CodePipeline artifact buckets
          "arn:aws:s3:::codepipeline-*-*",
        ]
      },
      {
        Action = [
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:BatchGetBuilds"
        ],
        Effect   = "Allow",
        Resource = aws_iam_role_policy_attachment.codepipeline_codebuild_attach.policy_arn
      }
      # If using CodeCommit, add permissions for CodeCommit
      # {
      #   Action = [
      #     "codecommit:GetBranch",
      #     "codecommit:GetCommit",
      #     "codecommit:UploadArchive",
      #     "codecommit:GetUploadArchiveStatus",
      #     "codecommit:GitPull"
      #   ],
      #   Effect   = "Allow",
      #   Resource = "*" # Restrict to specific repo ARN if known
      # }
      # If using GitHub, CodePipeline handles connection, no explicit IAM for source needed here
    ]
  })
}

# Attach CodeBuild policy to CodePipeline role for CodePipeline to invoke CodeBuild
resource "aws_iam_role_policy_attachment" "codepipeline_codebuild_attach" {
  policy_arn = aws_iam_role_policy.codebuild_policy.arn
  role       = aws_iam_role.codepipeline_role.name
}

output "website_url" {
  value       = "http://${aws_s3_bucket.static_website_bucket.website_endpoint}"
  description = "The URL of the static website hosted on S3."
}

output "s3_bucket_name" {
  value = aws_s3_bucket.static_website_bucket.id
}

output "codebuild_role_arn" {
  value = aws_iam_role.codebuild_role.arn
}

output "codepipeline_role_arn" {
  value = aws_iam_role.codepipeline_role.arn
}