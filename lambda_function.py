import boto3
import json

# Connect to DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table("ResumeViews")

def lambda_handler(event, context):
    # Get current counter views
    response = table.get_item(Key={'id': 'counter'})
    current_views = response['Item']['views']

    # Add 1 new view to counter
    new_views = current_views + 1

    # Put the new # of views in table
    table.put_item(Item={"id": "counter", "views": new_views})

    # Return JSON
    return {
        'statusCode': 200,
        "body": json.dumps({"views": int(new_views)})
    }

