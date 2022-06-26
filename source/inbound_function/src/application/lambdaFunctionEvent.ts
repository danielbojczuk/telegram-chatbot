export interface LambdaFunctionEvent {
  Records: [
    {
      messageId: string;
      receiptHandle: string;
      body: string;
      attributes: [Object];
      messageAttributes: Object;
      md5OfBody: string;
      eventSource: string;
      eventSourceARN: string;
      awsRegion: string;
    }
  ];
}
