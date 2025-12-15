import boto3
import json
from decimal import Decimal

# Connect to DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table("crc-views")

def lambda_handler(event, context):
    # Increment counter atomically using UpdateExpression
    response = table.update_item(
        Key={'id': 'counter'},
        UpdateExpression="SET #v = if_not_exists(#v, :start) + :inc",
        ExpressionAttributeNames={
            "#v": "views"
        },
        ExpressionAttributeValues={
            ":inc": 1,
            ":start": 0
        },
        ReturnValues="UPDATED_NEW"
    )

    new_views = int(response['Attributes']['views'])  # convert Decimal -> int

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',  # CORS
            'Access-Control-Allow-Methods': 'GET',
            'Cache-Control': 'no-store'
        },
        'body': json.dumps({"views": new_views})
    }
