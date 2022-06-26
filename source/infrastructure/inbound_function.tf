#Get the inbound lambda function code and zip it in the build directory.
data "archive_file" "inbound_function_zip" {
  type = "zip"

  source_dir  = "${local.build_directory}/inbound_function/dist"
  output_path = "${local.build_directory}/build/inbound_function.zip"
}

#Get the inbound lamnda function zip and uploadt it to S3.
resource "aws_s3_object" "inbound_function_s3" {
  bucket = var.s3_deployment_bucket

  key    = "inbound_function.zip"
  source = data.archive_file.inbound_function_zip.output_path

  etag = filemd5(data.archive_file.inbound_function_zip.output_path)
}

#Create the role to be assumed by the inbound lambda function.
resource "aws_iam_role" "inbound_function_lambda_execution_role" {
  name = local.inbound_lambda_execution_role_name

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

#Create the inbound lambda function.
resource "aws_lambda_function" "inbound_lambda_function" {
  function_name = local.inbound_lambda_function_name

  s3_bucket = var.s3_deployment_bucket
  s3_key    = aws_s3_object.inbound_function_s3.key

  runtime = "nodejs16.x"
  handler = "handler.handler"

  source_code_hash = data.archive_file.inbound_function_zip.output_base64sha256

  role = aws_iam_role.inbound_function_lambda_execution_role.arn

  environment {
    variables = {
      AWSRegion = local.aws_region,
      AWSAccountID = local.aws_account_id,
      OutboundQueueName = local.outbound_queue_name
    }
  }
}

#Attach the AWSLambdaBasicExecutionRole to the created role.
resource "aws_iam_role_policy_attachment" "inbound_function_execution_role_Policy_LambdaBasicExecution" {
  role       = aws_iam_role.inbound_function_lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#Create the policy allowing to post and read messages to the inbound and outbound queue.
resource "aws_iam_policy" "aws_lambda_sqs_inbound_outbound_policy" {

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
resource "aws_iam_role_policy_attachment" "inbound_function_execution_role_Policy_sqs" {
  role       = aws_iam_role.inbound_function_lambda_execution_role.name
  policy_arn = aws_iam_policy.aws_lambda_sqs_inbound_outbound_policy.arn
}

#Sets the inbound SQS as a lamnda trigger.
resource "aws_lambda_event_source_mapping" "event_source_mapping_inbound_function" {
  event_source_arn = aws_sqs_queue.inbound_queue.arn
  enabled          = true
  function_name    = aws_lambda_function.inbound_lambda_function.arn
  batch_size       = 1

  depends_on = [
    aws_iam_role_policy_attachment.inbound_function_execution_role_Policy_sqs
  ]
}