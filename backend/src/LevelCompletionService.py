import datetime
import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

from common import bad_request, request_handled, server_error, service_unavailable

stage = os.environ.get("STAGE", "dev")
client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))
table_name = f"Sokobubble-{stage}"

logger = logging.getLogger(__name__)


def handle_level_completion_put(event, context):
    logger.info(f"{event=}")

    request_json = json.loads(event["body"])
    time_stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        player = request_json["player"]
        level = request_json["level"]
        move_count = request_json["moveCount"]
        move_history = request_json["moveHistory"]
    except KeyError as e:
        return bad_request(str(e))

    try:
        response = client.put_item(
            TableName=table_name,
            Item={
                "PKEY": {"S": "Log"},
                "SKEY": {"S": f"EntryTime={time_stamp}"},
                "Player": {"S": player},
                "Level": {"N": str(level)},
                "MoveCount": {"N": str(move_count)},
                "MoveHistory": {"S": move_history}
            },
            ConditionExpression="attribute_not_exists(SKEY)"
        )
        logger.info(f"{response=}")
    except ClientError as e:
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            logger.warning(f"Failed to add log-entry due to clash")
            return service_unavailable()
        else:
            logger.warning(str(e))
            return server_error(str(e))

    improved = False
    try:
        response = client.update_item(
            TableName=table_name,
            Key={
                "PKEY": {"S": "HallOfFame"},
                "SKEY": {"S": f"Level={level}"},
            },
            UpdateExpression=f"SET Player = :player, MoveCount = :move_count, UpdateTime = :datetime",
            ConditionExpression="MoveCount > :move_count",
            ExpressionAttributeValues={
                ":move_count": {"N": str(move_count)},
                ":datetime": {"S": time_stamp},
                ":player": {"S": player},
            },
            ReturnValues="ALL_NEW",
            ReturnValuesOnConditionCheckFailure="ALL_OLD"
        )
        logger.info(f"{response=}")
        item = response["Attributes"]

        logger.info(f"Improved hi-score")
        improved = True

    except ClientError as e:
        logger.info(e.response)
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            logger.info(f"Did not improve hi-score")
            item = e.response["Item"]
        else:
            logger.warning(str(e))
            return server_error(str(e))

    return request_handled({
        "level": level,
        "player": item["Player"]["S"],
        "moveCount": int(item["MoveCount"]["N"]),
        "improved": improved
    })


logging.getLogger().setLevel(logging.INFO)
