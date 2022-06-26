# Manual Steps

Each service creation represents a step and you can find the necessary values to create them. These steps were used in the WAES Techtalk Demo.

_Prerequisites_:

- The role `WaesTechTalkChatBot_ApiGateway_Role` must exists and allows the API Gateway to post data to the Queues.
- The role `WaesTechTalkChatBot_LambdaFunctions_Role` must exists and allows the Lambda Functions to:
  - Read and Post messages into the Queues
  - Retrieve secrets from Secrets Manager

You can check the Article [How to Build a Reliable, Scalable, and Cost-Effective Telegram Bot](https://medium.com/wearewaes/how-to-build-a-reliable-scalable-and-cost-effective-telegram-bot-58ae2d6684b1) to understand how to create the services.

## Inbound SQS Queue

- Name: WaesTechTalkChatBot_Queue.fifo
- Let all the other options with the default values

## Inbound API Gateway

- Protocol: REST
- Create New API: New API
- Api Name: WaesTechTalkChatBot_Api

### Income API Gateway - Resource

- Name: WaesTechTalkChatBot_Api_Resource
- Path: batata

### Income API Gateway - Method

- HTTP Verb: POST
- Integration Type: AWS Service
  - AWS Region: eu-west-1
  - AWS Service: Simple Queue Service (SQS
  - HTTP Method: POST
  - Action Type: Use path override
  - Path override: `AWS Account ID`/WaesTechTalkChatBot_Queue.fifo
  - Execution role: arn:aws:iam::`AWS Account ID`:role/WaesTechTalkChatBot_ApiGateway_Role
  - Content Handling: Passthrought

### Change the integration request:

- Add the header:

  - Content-Type: 'application/x-www-form-urlencoded'

- Add Mapping Template:
  - Request body passthrought: Never
  - Content-Type: application/json
  - Template: Action=SendMessage&MessageGroupId=$context.requestId&MessageDeduplicationId=$context.requestId&MessageBody=$util.base64Encode($input.body)

### Deploy API:

- Deploy API to dev environment.

## Outbound SQS Queue

- Name: WaesTechTalkChatBot_OutboundQueue.fifo
- Let all the other options with the default values

## Inbound SQS Lambda

- Function name: WaesTechTalkChatBot_Inbound_Function
- Runtime: Node.js:16.x
- Architecture: arm64
- Change default execution role: WaesTechTalkChatBot_LambdaFunctions_Role

- Change Handler to handler.handler
- Upload zip file.
- Set OutboundQueueName env var: WaesTechTalkChatBot_OutboundQueue.fifo
- Set trigger:
  - SQS
  - arn:aws:sqs:eu-west-1:662642131450:WaesTechTalkChatBot_Queue.fifo
  - Batch size: 1

## Create telegram bot

- Username: waes_techtalk_telegram_bot

## Add token to secret manager

- Secret Name: WaesTechTalkChatBot_TelegramBotToken
- Secret Key: token

## Outbound SQS Lambda

- Function name: WaesTechTalkChatBot_OutBound_Function
- Runtime: Node.js:16.x
- Architecture: arm64
- Change default execution role: WaesTechTalkChatBot_LambdaFunctions_Role

- Change Handler to handler.handler
- Upload zip file.
- Set TelegramBotToken env var: WaesTechTalkChatBot_TelegramBotToken
- Set trigger:
  - SQS
  - arn:aws:sqs:eu-west-1:662642131450:WaesTechTalkChatBot_OutboundQueue.fifo
  - Batch size: 1

## Set Webhook

- GET - URL: https://api.telegram.org/bot{token}/setWebhook?url={urlApiGateway}
