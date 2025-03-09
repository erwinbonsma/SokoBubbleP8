import logging
import os

import boto3
from botocore.exceptions import ClientError

from common import request_handled, server_error

stage = os.environ.get("STAGE", "dev")
client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))
table_name = f"Sokobubble-{stage}"

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handle_hall_of_fame_get(event, context):
    try:
        response = client.query(
            TableName=table_name,
            KeyConditionExpression="PKEY = :pkey",
            ExpressionAttributeValues={":pkey": {"S": "HallOfFame"}}
        )
        logger.info(f"{response=}")
    except ClientError as e:
        logger.warning(str(e))
        return server_error(str(e))

    return request_handled({
        "hallOfFame": [
            {
                "player": item["Player"]["S"],
                "moveCount": int(item["MoveCount"]["N"])
            }
            for item in response["Items"]
        ]
    })
