#Creates the outbound queue.
resource "aws_sqs_queue" "outbound_queue" {
  name = local.outbound_queue_name
  fifo_queue = true
  content_based_deduplication = false
}

#Creates the role to be assumed by the Lambda function.
resource "aws_iam_role" "outbound_lambda_execution_role" {
  name = local.outbound_lambda_execution_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

#Get the outbound lambda function code and zip it in the build directory.
data "archive_file" "lambda_outbound_zip" {
  type = "zip"

  source_dir  = "${local.build_directory}/outbound_function/dist/"
  output_path = "${local.build_directory}/build/outbound_function.zip"
}

#Get the outbound lamnda function zip and uploadt it to S3.
resource "aws_s3_object" "lambda_outbound_s3" {
  bucket = var.s3_deployment_bucket

  key    = "outbound_function.zip"
  source = data.archive_file.lambda_outbound_zip.output_path

  etag = filemd5(data.archive_file.lambda_outbound_zip.output_path)
}

#Create the outbound lambda function.
resource "aws_lambda_function" "lambda_outbound_function" {
  function_name = local.outbound_lambda_function_name

  s3_bucket = var.s3_deployment_bucket
  s3_key    = aws_s3_object.lambda_outbound_s3.key

  runtime = "nodejs16.x"
  handler = "handler.handler"

  source_code_hash = data.archive_file.lambda_outbound_zip.output_base64sha256

  role = aws_iam_role.outbound_lambda_execution_role.arn

  environment {
    variables = {
      TelegramBotToken = var.secrets_manager_id,
    }
  }
}

#Attach the AWSLambdaBasicExecutionRole to the created role.
resource "aws_iam_role_policy_attachment" "outbound_lambda_execution_role_Policy_LambdaBasicExecution" {
  role       = aws_iam_role.outbound_lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#Create the policy allowing to post and read messages to the inbound and outbound queue.
resource "aws_iam_policy" "aws_lambda_sqs_outbound_policy" {

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "sqs:SendMessage",
              "sqs:DeleteMessage",
              "sqs:ChangeMessageVisibility",
              "sqs:ReceiveMessage",
              "sqs:PurgeQueue",
              "sqs:GetQueueAttributes"
            ],
            "Resource": ["${aws_sqs_queue.inbound_queue.arn}", "${aws_sqs_queue.outbound_queue.arn}"]
        }
    ]
}
EOF

  depends_on = [
    aws_sqs_queue.inbound_queue,
    aws_sqs_queue.outbound_queue
  ]
}

#Attach the created policy to the created role.
resource "aws_iam_role_policy_attachment" "outbound_lambda_execution_role_Policy_sqs" {
  role       = aws_iam_role.outbound_lambda_execution_role.name
  policy_arn = aws_iam_policy.aws_lambda_sqs_outbound_policy.arn
}

#Sets the inbound SQS as a lamnda trigger.
resource "aws_lambda_event_source_mapping" "event_source_mapping_outbound" {
  event_source_arn = aws_sqs_queue.outbound_queue.arn
  enabled          = true
  function_name    = aws_lambda_function.lambda_outbound_function.arn
  batch_size       = 1

  depends_on = [
    aws_iam_role_policy_attachment.outbound_lambda_execution_role_Policy_sqs
  ]
}

#Create the policy allowing the the role to get the secrets from the secrets manager.
resource "aws_iam_policy" "aws_lambda_secrets_policy" {

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "secretsmanager:GetResourcePolicy",
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret",
              "secretsmanager:ListSecretVersionIds",
              "secretsmanager:ListSecrets"
            ],
            "Resource": "*"
        }
    ]
}
EOF

}

#Attach the created policy to the created role.
resource "aws_iam_role_policy_attachment" "outbound_lambda_execution_role_Policy_secrets" {
  role       = aws_iam_role.outbound_lambda_execution_role.name
  policy_arn = aws_iam_policy.aws_lambda_secrets_policy.arn
}