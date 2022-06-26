import { Context } from "aws-lambda";
import { LambdaFunctionEvent } from "./application/lambdaFunctionEvent";
import { TelegramMessage } from "./application/telegramMessage";
import * as AWS from "aws-sdk";
import axios from "axios";

export const handler = async (event: LambdaFunctionEvent, context: Context) => {
  try {
    const message: TelegramMessage = JSON.parse(event.Records[0].body);

    const secretManagerClient = new AWS.SecretsManager({
      region: process.env.AWS_REGION,
    });
    const secret = await secretManagerClient
      .getSecretValue({
        SecretId: process.env.TelegramBotToken || "TelegramBotToken",
      })
      .promise();
    if (!secret.SecretString) {
      throw new Error("No telegram Key");
    }

    const token = JSON.parse(secret.SecretString).token;

    const url = `https://api.telegram.org/bot${token}/sendMessage?chat_id=${
      message.chatid
    }&parse_mode=Markdown&text=${encodeURIComponent(message.message)}`;

    const { status } = await axios.get(url);

    console.log("status call", status);
  } catch (error) {
    console.log(error);
    throw error;
  }
};
