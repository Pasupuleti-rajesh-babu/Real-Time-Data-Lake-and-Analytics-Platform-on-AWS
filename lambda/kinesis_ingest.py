import json
import boto3
import base64
import os
from datetime import datetime

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Process Kinesis records and store them in S3 raw zone
    """
    raw_bucket = os.environ['RAW_BUCKET']
    
    for record in event['Records']:
        # Decode the Kinesis data
        payload = base64.b64decode(record['kinesis']['data'])
        data = json.loads(payload)
        
        # Generate S3 key with timestamp
        timestamp = datetime.now().strftime('%Y/%m/%d/%H/%M/%S')
        partition_key = record['kinesis']['partitionKey']
        s3_key = f"raw/{timestamp}/{partition_key}.json"
        
        # Store in S3
        s3_client.put_object(
            Bucket=raw_bucket,
            Key=s3_key,
            Body=json.dumps(data),
            ContentType='application/json'
        )
        
    return {
        'statusCode': 200,
        'body': json.dumps('Successfully processed records')
    } 