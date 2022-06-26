# Telegram Chatbot

This project is an extension of the Article [How to Build a Reliable, Scalable, and Cost-Effective Telegram Bot](https://medium.com/wearewaes/how-to-build-a-reliable-scalable-and-cost-effective-telegram-bot-58ae2d6684b1) and the second presentation of this [WAES TechTalk](https://youtu.be/VIzLl-c71fI).

## Building the bot step by step using the Web AWS Console

You can check the [MANUAL_STEPS](MANUAL_STEPS.md) for the all the necessary steps.

## Building the bot with terraform

### Prerequisites

- AWS Console configured with a user allowed to create Lambda Functions, Api Gateways, SQS Queues, IAM policies and IAM roles. This project is currently using the default profile (you can change in the `source/infrastructure/locals.tf`)
- NodeJS installed to build the functions.
- Terraform installed to deploy the bot to AWS

### Preparation

- You need to create an S3 bucket in the same region you will deploy this service. This S3 bucket will be used in the deployment to upload the lambda function. Currently the project is using eu-west-1 (you can change in the `source/infrastructure/locals.tf`).
- You need to create your bot (check the article to understand how) with Telegram and store the Token in the secret manager. The type should be `Other type of secret`, the key should be `token` and the value should be the token provided by Telegram.

### Installation

#### Building the lambda functions

- Go to the directory `source/inbound_function` and execute the command:`npm run build`.

- Go to the directory `source/outbound_function` and execute the command:`npm run build`.

#### Deploying the service to AWS

- Go to the directory `source/infrastructure` and execute the commands:

```
terraform init
```

And then:

```
terraform apply
```

Terraform will ask you for the bucket name and the secret name from the Secrets Manager.

After terraform finishes the deployment you can set the Telegram Bot WebHook (check the article to understand how).
