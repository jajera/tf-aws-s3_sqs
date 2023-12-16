variable "use_case" {
  default = "tf-aws-s3_sqs"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_resourcegroups_group" "example" {
  name        = "tf-rg-example"
  description = "Resource group for example resources"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "Owner",
          "Values": ["John Ajera"]
        },
        {
          "Key": "UseCase",
          "Values": ["${var.use_case}"]
        }
      ]
    }
    JSON
  }

  tags = {
    Name    = "tf-rg-example"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

data "aws_iam_policy_document" "queue" {
  statement {
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = ["arn:aws:sqs:*:*:tf-sqs-example"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.example.arn]
    }
  }
}

resource "aws_sqs_queue" "example" {
  name                      = "tf-sqs-example"
  receive_wait_time_seconds = 20
  message_retention_seconds = 60
  policy                    = data.aws_iam_policy_document.queue.json

  tags = {
    Name    = "tf-sqs-example"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket" "example" {
  bucket        = "example-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "tf-s3-bucket-example"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket_notification" "example" {
  bucket = aws_s3_bucket.example.id

  queue {
    queue_arn = aws_sqs_queue.example.arn
    events    = ["s3:ObjectCreated:*"]
  }
}
