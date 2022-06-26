#Creates the inbound queue
resource "aws_sqs_queue" "inbound_queue" {
  name = local.inbound_queue_name
  fifo_queue = true
  content_based_deduplication = false
}

#Creates the role that will be used by the API Gateway to access the SQS queue.
resource "aws_iam_role" "inbound_api_gateway_role" {
  name = local.inbound_api_execution_role

  assume_role_policy = jsonencode({
          "Version": "2012-10-17",
          "Statement": [
              {
                "Sid": "",
                "Effect": "Allow",
                "Principal": { "Service": "apigateway.amazonaws.com" },
                "Action": "sts:AssumeRole",
              },
            ],
        })
}

#Creates the policy allowing posting in the Inbound Queue.
resource "aws_iam_policy" "inbound_sqs_policy" {

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:SendMessage"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.inbound_queue.arn}"
    }
  ]
}
EOF
}

#Attach the created policy to the created role.
resource "aws_iam_role_policy_attachment" "sqs-inbound-policy-attach" {
  role       = aws_iam_role.inbound_api_gateway_role.name
  policy_arn = aws_iam_policy.inbound_sqs_policy.arn

  depends_on = [
    aws_iam_role.inbound_api_gateway_role,
    aws_iam_policy.inbound_sqs_policy
  ]
}

#Creates an API Gateway
resource "aws_api_gateway_rest_api" "inbound_api_gateway" {
  name          = local.inbound_api_name
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

#Creates an Api Gateway Resource
resource "aws_api_gateway_resource" "inbound_api_gateway_inbound_resource" {
  parent_id   = aws_api_gateway_rest_api.inbound_api_gateway.root_resource_id
  path_part   = local.inbound_api_resource_pah
  rest_api_id = aws_api_gateway_rest_api.inbound_api_gateway.id

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
  ]
}

#Creates an API Gateway Resource Method
resource "aws_api_gateway_method" "inbound_api_gateway_inbound_resource_post_method" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.inbound_api_gateway_inbound_resource.id
  rest_api_id   = aws_api_gateway_rest_api.inbound_api_gateway.id

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
    aws_api_gateway_resource.inbound_api_gateway_inbound_resource,
  ]
}

#Sets the integration for the API Gateway Resource Method to post Messages to SQS Queue.
resource "aws_api_gateway_integration" "inbound_api_gateway_inbound_resource_post_method_integration" {
  rest_api_id          = aws_api_gateway_rest_api.inbound_api_gateway.id
  resource_id          = aws_api_gateway_resource.inbound_api_gateway_inbound_resource.id
  http_method          = aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method.http_method
  type                 = "AWS"
  integration_http_method = "POST"
  uri = "arn:aws:apigateway:${local.aws_region}:sqs:path/${local.aws_account_id}/${local.inbound_queue_name}"
  credentials = aws_iam_role.inbound_api_gateway_role.arn
 
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageGroupId=$context.requestId&MessageDeduplicationId=$context.requestId&MessageBody=$util.base64Encode($input.body)"
  }

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
    aws_api_gateway_resource.inbound_api_gateway_inbound_resource,
    aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method
  ]
}

#Create an deployment to the API Gateway
resource "aws_api_gateway_deployment" "inbound_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.inbound_api_gateway.id
  stage_description = "Deployed at ${timestamp()}"


  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.inbound_api_gateway_inbound_resource.id,
      aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method.id,
      aws_api_gateway_integration.inbound_api_gateway_inbound_resource_post_method_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
  ]
}

#Creates an stage to API Gateway
resource "aws_api_gateway_stage" "inbound_api_gateway_stage" {
  deployment_id = aws_api_gateway_deployment.inbound_api_gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.inbound_api_gateway.id
  stage_name    = local.inbound_api_stage_name

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
    aws_api_gateway_deployment.inbound_api_gateway_deployment,
  ]
}

#Till the end of the file, the default responses are being created.
resource "aws_api_gateway_method_response" "inbound_api_gateway_inbound_resource_post_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.inbound_api_gateway.id
  resource_id = aws_api_gateway_resource.inbound_api_gateway_inbound_resource.id
  http_method = aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method.http_method
  status_code = "200"

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
    aws_api_gateway_resource.inbound_api_gateway_inbound_resource,
    aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method
  ]
}

resource "aws_api_gateway_method_response" "inbound_api_gateway_inbound_resource_post_method_response_500" {
  rest_api_id = aws_api_gateway_rest_api.inbound_api_gateway.id
  resource_id = aws_api_gateway_resource.inbound_api_gateway_inbound_resource.id
  http_method = aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method.http_method
  status_code = "500"

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
    aws_api_gateway_resource.inbound_api_gateway_inbound_resource,
    aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method
  ]
}

resource "aws_api_gateway_integration_response" "inbound_api_gateway_inbound_resource_post_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.inbound_api_gateway.id
  resource_id = aws_api_gateway_resource.inbound_api_gateway_inbound_resource.id
  http_method = aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method.http_method
  status_code = aws_api_gateway_method_response.inbound_api_gateway_inbound_resource_post_method_response_200.status_code
  selection_pattern = "200"

  response_templates = {
    "application/xml" = "{\"message\": \"message received\"}'"
  }

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
    aws_api_gateway_resource.inbound_api_gateway_inbound_resource,
    aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method,
    aws_api_gateway_method_response.inbound_api_gateway_inbound_resource_post_method_response_200
  ]
}

resource "aws_api_gateway_integration_response" "inbound_api_gateway_inbound_resource_post_integration_response_500" {
  rest_api_id = aws_api_gateway_rest_api.inbound_api_gateway.id
  resource_id = aws_api_gateway_resource.inbound_api_gateway_inbound_resource.id
  http_method = aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method.http_method
  status_code = aws_api_gateway_method_response.inbound_api_gateway_inbound_resource_post_method_response_500.status_code
  selection_pattern = ""

  response_templates = {
    "application/xml" = "{\"message\": \"message not received\"}'"
  }

  depends_on = [
    aws_api_gateway_rest_api.inbound_api_gateway,
    aws_api_gateway_resource.inbound_api_gateway_inbound_resource,
    aws_api_gateway_method.inbound_api_gateway_inbound_resource_post_method,
    aws_api_gateway_method_response.inbound_api_gateway_inbound_resource_post_method_response_500
  ]
}