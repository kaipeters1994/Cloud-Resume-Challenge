import boto3
import json

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table("ResumeViews")  # make sure table name matches

def lambda_handler(event, context):
    # Atomically increment the counter
    response = table.update_item(
        Key={"id": "counter"},
        UpdateExpression="ADD views :inc",
        ExpressionAttributeValues={":inc": 1},
        ReturnValues="UPDATED_NEW"
    )

    new_views = response["Attributes"]["views"]

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"views": new_views})
    }
