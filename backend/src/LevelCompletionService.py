import datetime
import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

from common import bad_request, request_handled, server_error, service_unavailable

NUM_LEVELS = 24
MIN_MOVE_COUNT = 20
MAX_MOVE_COUNT = 999

STAGE = os.environ.get("STAGE", "dev")
TABLE_NAME = f"Sokobubble-{STAGE}"

client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))
logger = logging.getLogger(__name__)


def handle_level_completion_post(event, context):
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

    if (
        len(player) > 8
        or (level < 1 or level > NUM_LEVELS)
        or (move_count < MIN_MOVE_COUNT or move_count > MAX_MOVE_COUNT)
        or len(move_history) > move_count
    ):
        return bad_request()

    try:
        response = client.put_item(
            TableName=TABLE_NAME,
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
            TableName=TABLE_NAME,
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
        "level": int(level),
        "player": item["Player"]["S"],
        "moveCount": int(item["MoveCount"]["N"]),
        "improved": improved
    })


logging.getLogger().setLevel(logging.INFO)
