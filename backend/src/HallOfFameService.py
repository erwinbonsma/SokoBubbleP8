import logging
import os

import boto3
from botocore.exceptions import ClientError

from common import bad_request, request_handled, server_error, DEFAULT_TABLE_ID

STAGE = os.environ.get("STAGE", "dev")
TABLE_NAME = f"Sokobubble-{STAGE}"

client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handle_hall_of_fame_get(event, context):
    id = event.get("queryStringParameters", {}).get("id", DEFAULT_TABLE_ID)
    logger.info(f"Request for Hall of Fame {id=}")

    try:
        response = client.query(
            TableName=TABLE_NAME,
            KeyConditionExpression="PKEY = :pkey AND begins_with(SKEY, :skey_prefix)",
            ExpressionAttributeValues={
                ":pkey": {"S": f"HallOfFame#{id}"},
                ":skey_prefix": {"S": "Level="}
            }
        )
        logger.info(f"{response=}")
    except ClientError as e:
        logger.warning(str(e))
        return server_error(str(e))

    return request_handled({
        "hallOfFame": {
            int(item["SKEY"]["S"][6:]): {
                "player": item["Player"]["S"],
                "moveCount": int(item["MoveCount"]["N"])
            }
            for item in response["Items"]
        }
    })


def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    if method == "GET":
        return handle_hall_of_fame_get(event, context)
    elif method == "OPTIONS":
        return request_handled()

    logger.error(f"Unsupported event: {event}")
    return bad_request()
