from decimal import Decimal
import json
import os

import boto3


table_name = os.environ['TABLE_NAME']
record_ttl = float(os.environ['RECORD_TTL'])

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(table_name)


def handler(event, context):
    timestamp = event['timestamp'] / 1000
    item = {
         'device': event['device_id'],
         'timestamp': timestamp,
         'ttl': timestamp + record_ttl,
         'payload': event['payload'],
    }

    formatted_item = json.loads(json.dumps(item), parse_float=Decimal)
    table.put_item(Item=formatted_item)
