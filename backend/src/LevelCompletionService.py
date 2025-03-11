import datetime
import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

from common import (
    bad_request,
    request_handled,
    server_error,
    service_unavailable,
    DEFAULT_TABLE_ID,
)

NUM_LEVELS = 24
MIN_MOVE_COUNT = 20
MAX_MOVE_COUNT = 999

STAGE = os.environ.get("STAGE", "dev")
TABLE_NAME = f"Sokobubble-{STAGE}"

client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def put_hof_entry(
    table_id, time_stamp, player, level, move_count
):
    """
    Adds initial entry to given Hall of Fame
    """
    logger.info(f"Adding new entry: {table_id=}, {level=}")
    try:
        item = {
            "PKEY": {"S": f"HallOfFame#{table_id}"},
            "SKEY": {"S": f"Level={level}"},
            "Player": {"S": player},
            "MoveCount": {"N": str(move_count)},
            "UpdateTime": {"S": time_stamp},
        }
        client.put_item(
            TableName=TABLE_NAME,
            Item=item,
            ConditionExpression="attribute_not_exists(PKEY)",
        )
        logger.info(f"Added entry: {item=}")
        return item
    except ClientError as e:
        logger.warning("Error adding initial HOF entry: ", e)
        raise


def try_update_hof_entry(
    table_id, time_stamp, player, level, move_count
):
    """
    Tries to update entry for given Hall of Fame.
    Creates entry when one did not exist yet.
    Returns item for resulting entry.
    The "improved" field indicates whether score was improved.
    """
    try:
        logger.info(f"Conditionally updating HOF entry for {table_id=}, {level=}")
        response = client.update_item(
            TableName=TABLE_NAME,
            Key={
                "PKEY": {"S": f"HallOfFame#{table_id}"},
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
        logger.info(f"Updated HOF entry: {response=}")
        item = response["Attributes"]

        logger.info(f"Improved hi-score")
        item["Improved"] = True
    except ClientError as e:
        logger.info(e.response)
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            if "Item" in e.response:
                logger.info("Did not improve existing entry")
                item = e.response["Item"]
                item["Improved"] = False
            else:
                logger.info("No entry exists yet")
                item = put_hof_entry(table_id, time_stamp, player, level, move_count)
                item["Improved"] = True
        else:
            raise

    logger.info(f"Hi-score improved = {item['Improved']}")
    return item


def handle_level_completion_post(event, context):
    logger.info(f"{event=}")

    request_json = json.loads(event["body"])
    time_stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        player = request_json["player"]
        level = request_json["level"]
        move_count = request_json["moveCount"]
        move_history = request_json["moveHistory"]
        table_id = request_json.get("tableId", DEFAULT_TABLE_ID)
    except KeyError as e:
        return bad_request(str(e))

    if (
        len(player) > 8
        or (level < 1 or level > NUM_LEVELS)
        or (move_count < MIN_MOVE_COUNT or move_count > MAX_MOVE_COUNT)
        or len(move_history) > move_count
        or len(table_id) > 8
    ):
        return bad_request()

    try:
        logger.info(f"Storing log entry for {table_id}")
        client.put_item(
            TableName=TABLE_NAME,
            Item={
                "PKEY": {"S": "Log"},
                "SKEY": {"S": f"EntryTime={time_stamp}"},
                "Player": {"S": player},
                "Level": {"N": str(level)},
                "MoveCount": {"N": str(move_count)},
                "MoveHistory": {"S": move_history},
                "Table": {"S": table_id},
            },
            ConditionExpression="attribute_not_exists(PKEY)"
        )
        logger.info("Stored log entry")
    except ClientError as e:
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            logger.warning(f"Failed to add log-entry due to clash")
            return service_unavailable()
        else:
            logger.warning(str(e))
            return server_error(str(e))

    try:
        item = try_update_hof_entry(table_id, time_stamp, player, level, move_count)
        if item["Improved"] and table_id != DEFAULT_TABLE_ID:
            try_update_hof_entry(
                DEFAULT_TABLE_ID, time_stamp, player, level, move_count
            )
    except ClientError as e:
        logger.warning(str(e))
        return server_error(str(e))

    return request_handled({
        "level": int(level),
        "player": item["Player"]["S"],
        "moveCount": int(item["MoveCount"]["N"]),
        "improved": item["Improved"]
    })


logging.getLogger().setLevel(logging.INFO)
