import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
    DynamoDBDocumentClient,
    PutCommand,
} from "@aws-sdk/lib-dynamodb";


const tableName = process.env.TABLE_NAME;
const recordTtl = process.env.RECORD_TTL;


const client = new DynamoDBClient();
const dynamo = DynamoDBDocumentClient.from(client);


export const handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    await dynamo.send(
        new PutCommand({
            TableName: tableName,
            Item: {
                device: event.device_id,
                timestamp: event.timestamp / 1000,
                ttl: event.timestamp / 1000 + Number(recordTtl),
                payload: event.payload,
            },
        })
    );

    console.log("Data saved successfully.");
};
