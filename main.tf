data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "aws-lambda" {
  name        = "lambda-function"
  path        = "/"
  description = "My test policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:CreateNetworkInterface",
                "ec2:AttachNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "autoscaling:CompleteLifecycleAction",
                "ec2:DeleteNetworkInterface"
            ]
        }
        ]
})
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.aws-lambda.arn
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-lambdaRole-waf"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_file = "${path.module}/code/lambda_function.py"
  output_path = "nametest.zip"
}

resource "aws_lambda_function" "test_lambda_function" {
  function_name    = "lambdaTest"
  filename         = "nametest.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.9"
  handler          = "lambda_function.lambda_handler"
  timeout          = 10
   tags = {
    Name = "sentineal_lambda",
    "Artifactory" = "Artifactory"
 
  }
  vpc_config {
    # Every subnet should be able to reach an EFS mount target in the same Availability Zone. Cross-AZ mounts are not permitted.
    subnet_ids         = data.aws_subnets.selected.ids
    security_group_ids = ["sg-0e64e6f3425a26c4c"]
  }
}

data "aws_subnets" "selected" {
  

  tags = {
    Tier = "Private"
  }

}



resource "aws_s3_bucket" "b" {
  bucket = "my-tf-test-bucket-sentinel"

  #tags = {
  #  Name        = "My bucket"
  #  Environment = "Dev"
  #}

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.mykey.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }


}

resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.selected.ids)
  id = each.key
  
}

output "subnets_public_flag" {
  value = [for s in data.aws_subnet.selected : s.map_public_ip_on_launch] 
}


