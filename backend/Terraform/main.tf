# Create S3 bucket
resource "aws_s3_bucket" "crc_static_bucket" {
  bucket = "kp-cloud-resume-challenge-tf45436334"
  force_destroy = true
}

# Create static website in S3
resource "aws_s3_bucket_website_configuration" "s3_static_site" {
  bucket = "kp-cloud-resume-challenge-tf45436334"
    index_document {
      suffix = "index.html"
    }
    error_document {
      key = "error.html"
    }
}

# Create Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "crc_oai" {
  comment = "OAI for CloudResumeChallenge"
}

# Attach bucket policy allowing OAI to read s3
resource "aws_s3_bucket_policy" "crc_bucket_policy" {
  bucket = aws_s3_bucket.crc_static_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.crc_oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.crc_static_bucket.arn}/*"
      }
    ]
  })
}


# Create CloudFront Distribution 
resource "aws_cloudfront_distribution" "crc_cf_distribution" {
  origin {
    domain_name         = aws_s3_bucket.crc_static_bucket.bucket_regional_domain_name    # Pointing at static
    origin_id           = "S3-crc-bucket"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.crc_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true   # Enable distribution
  is_ipv6_enabled     = true   # Enable IPv6
  default_root_object = "index.html"  # Point to index in bucket

  default_cache_behavior {
    allowed_methods   = ["GET", "HEAD"]   # Allow GET and Head
    cached_methods    = ["GET", "HEAD"]   # Allow caching of GET and HEAD
    target_origin_id  = "S3-crc-bucket"   # Point to Origin ID

    viewer_protocol_policy = "redirect-to-https"   # Enable HTTPS

    forwarded_values {       # No forwarding cookies or queries
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {       # No Geo restrictions
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {    # Default certificate
    cloudfront_default_certificate = true
  }
}

# DynamoDB table
resource "aws_dynamodb_table" "crc_views" {
  name         = "crc-views"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Initialize the counter
resource "aws_dynamodb_table_item" "initial_counter" {
  table_name = aws_dynamodb_table.crc_views.name
  hash_key   = "id"
  item = <<ITEM
{
  "id": {"S": "counter"},
  "views": {"N": "0"}
}
ITEM
}

# Create lambda role to interact with DynamoDB
resource "aws_iam_role" "lambda_role" {
  name = "crc_lambda_role"

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

# Attach policy
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role          = aws_iam_role.lambda_role.name
  policy_arn    = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Create lambda function
resource "aws_lambda_function" "crc_counter" {
  function_name = "crc-view-counter"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  filename      = "lambda_function_payload.zip"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")
}

# Create the API Gateway
resource "aws_apigatewayv2_api" "crc_http_api" {
  name          = "arc-http-api"
  protocol_type = "HTTP"
}

# Create integration between API and Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.crc_http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.crc_counter.arn
  payload_format_version = "2.0"
}

# Create API Route
resource "aws_apigatewayv2_route" "counter_route" {
  api_id                 = aws_apigatewayv2_api.crc_http_api.id
  route_key              = "GET /counter"
  target                 = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "allow_http_api" {
  statement_id    = "AllowExecutionFromHttpAPI"
  action          = "lambda:InvokeFunction"
  function_name   = aws_lambda_function.crc_counter.function_name
  principal       = "apigateway.amazonaws.com"
  source_arn      = "${aws_apigatewayv2_api.crc_http_api.execution_arn}/*/*"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "crc_stage" {
  api_id                 = aws_apigatewayv2_api.crc_http_api.id
  name                   = "$default"
  auto_deploy            = true
}

# Adding CloudWatch Permissions
# Attach CloudWatch logs permissions to Lambda role
resource "aws_iam_role_policy" "lambda_cloudwatch_logs" {
  name = "crc-lambda-logs-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}




























