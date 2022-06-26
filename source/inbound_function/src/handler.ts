import { Context } from "aws-lambda";
import { SendMessageCommand, SQSClient } from "@aws-sdk/client-sqs";
import { LambdaFunctionEvent } from "./application/lambdaFunctionEvent";
import { TelegramMessage } from "./application/telegramMessage";
import { v4 as uuidv4 } from "uuid";

export const handler = async (event: LambdaFunctionEvent, context: Context) => {
  try {
    const sqsClient = new SQSClient({ region: process.env.AWSRegion });
    const bodyMessage = Buffer.from(event.Records[0].body, "base64").toString(
      "binary"
    );
    const telegramMessage: TelegramMessage = JSON.parse(bodyMessage);
    const awsAccountID = context.invokedFunctionArn.split(":")[4];
    const params = {
      MessageGroupId: `${telegramMessage.message.chat.id}`,
      MessageDeduplicationId: uuidv4(),
      MessageBody: JSON.stringify({
        chatid: telegramMessage.message.chat.id,
        message: `You typed: ${telegramMessage.message.text}`,
      }),
      QueueUrl: `https://sqs.${process.env.AWS_REGION}.amazonaws.com/${awsAccountID}/${process.env.OutboundQueueName}`,
    };
    const data = await sqsClient.send(new SendMessageCommand(params));
  } catch (error) {
    console.log(error);
    throw error;
  }
};
