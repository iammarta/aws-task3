resource "aws_s3_bucket" "website_bucket" {
  bucket = "singlepage-webapp-task3-unique-id"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id
  index_document { suffix = "index.html" }
  error_document { key    = "error.html" }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.website_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  depends_on = [aws_s3_bucket_public_access_block.public_access]
  bucket     = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
    }]
  })
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "pipeline-artifacts-task3-unique-id"
}

resource "aws_codestarconnections_connection" "github_conn" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_iam_role" "pipeline_role" {
  name = "codepipeline-role-task3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "pipeline_policy" {
  name = "codepipeline-policy"
  role = aws_iam_role.pipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.pipeline_artifacts.arn}",
          "${aws_s3_bucket.pipeline_artifacts.arn}/*",
          "${aws_s3_bucket.website_bucket.arn}",
          "${aws_s3_bucket.website_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["codestar-connections:UseConnection"]
        Resource = aws_codestarconnections_connection.github_conn.arn
      }
    ]
  })
}

resource "aws_codepipeline" "static_web_pipeline" {
  name     = "static-website-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_conn.arn
        FullRepositoryId = "iammarta/aws-task3"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["source_output"]
      version         = "1"
      configuration = {
        BucketName = aws_s3_bucket.website_bucket.bucket
        Extract    = "true"
      }
    }
  }
}
