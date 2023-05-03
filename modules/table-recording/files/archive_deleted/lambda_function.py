import json
import os

import boto3


firehose_client = boto3.client('firehose')
firehose_name = os.environ['FIREHOSE_NAME']
batch_size = int(os.environ['BATCH_SIZE'])


def handler(event, context):
    removed_items = []
    print("Received %d records." % len(event['Records']))

    for record in event['Records']:
        if record['eventName'] == 'REMOVE':
            removed_items.append(record['dynamodb']['OldImage'])

    print("Handling %d removed items." % len(removed_items))
    put_items_to_firehose(removed_items)


def put_items_to_firehose(items):
    n_items = len(items)

    if n_items == 0:
        return
    
    batches = [items[i*batch_size:(i+1)*batch_size] for i in range((len(items)-1) // batch_size + 1)] 
    n_failures = 0
    for batch in batches:
        batch_message = [{'Data': json.dumps(batch) + '\n'}]
        result = firehose_client.put_record_batch(
            DeliveryStreamName=firehose_name,
            Records=batch_message,
        )
    
        if result:
            n_failures += result['FailedPutCount']

    print("All items processed (%d failures)." % n_failures)
