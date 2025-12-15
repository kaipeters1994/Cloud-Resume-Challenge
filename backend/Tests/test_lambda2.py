import boto3
import json
import pytest
from moto import mock_aws
from lambda_function import lambda_handler

# Set up fake DynamoDB Table to avoid using live service


@pytest.fixture
def dynamodb_table():
    with mock_aws():
        dynamodb = boto3.resource("dynamodb", region_name="us-east-1")

        # Create the table
        table = dynamodb.create_table(
            TableName="ResumeViews",
            KeySchema=[
                {"AttributeName": "id", "KeyType": "HASH"}
            ],
            AttributeDefinitions=[
                {"AttributeName": "id", "AttributeType": "S"}
            ],
            BillingMode="PAY_PER_REQUEST"
        )

        # Initial data
        table.put_item(
            Item={
                "id": "counter",
                "views": 0
            }
        )

        # This will destroy the table adter the test - no clean up
        yield table

# Define the test


def test_lambda_increments_counter(dynamodb_table):
    event = {}
    context = {}
    response = lambda_handler(event, context)
    body = json.loads(response["body"])
    # Assertions 200 for API os correct, make sure its intiger, and that +1 logic works
    assert response["statusCode"] == 200
    assert "views" in body
    assert isinstance(body["views"], int)
    assert body["views"] == 1
