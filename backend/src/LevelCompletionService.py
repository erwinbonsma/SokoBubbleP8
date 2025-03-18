from dataclasses import dataclass
import datetime
import json
import logging
import os
from typing import Optional

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


@dataclass
class LevelCompletion:
    player: str
    level: int
    level_id: Optional[int]
    update_time: str
    move_count: int
    move_history: str

    def __post_init__(self):
        if (
            len(self.player) > 8
            or (self.level < 1 or self.level > NUM_LEVELS)
            or (self.move_count < MIN_MOVE_COUNT or self.move_count > MAX_MOVE_COUNT)
            or len(self.move_history) > self.move_count
        ):
            raise ValueError("Field validation failed")

    @property
    def date_str(self):
        return self.update_time[:self.update_time.find(" ")]

    @staticmethod
    def from_json(json):
        return LevelCompletion(
            player=json["player"],
            level=json["level"],
            level_id=json.get("levelId"),
            move_count=json["moveCount"],
            move_history=json["moveHistory"],
            update_time=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )


STAGE = os.environ.get("STAGE", "dev")
TABLE_NAME = f"Sokobubble-{STAGE}"

client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def put_player_score(lc: LevelCompletion):
    logger.info(f"Adding new player score entry")
    try:
        item = {
            "PKEY": {"S": f"Player#{lc.player}"},
            "SKEY": {"S": f"LevelId={lc.level_id}"},
            "UpdateTime": {"S": lc.update_time},
            "MoveCount": {"N": str(lc.move_count)},
            "MoveHistory": {"S": lc.move_history},
        }
        client.put_item(
            TableName=TABLE_NAME,
            Item=item,
            ConditionExpression="attribute_not_exists(PKEY)",
        )
        logger.info(f"Added entry: {item=}")
    except ClientError as e:
        logger.warning("Error adding initial score entry: ", e)
        raise


def try_update_player_score(lc: LevelCompletion):
    try:
        logger.info(f"Conditionally updating player score")
        client.update_item(
            TableName=TABLE_NAME,
            Key={
                "PKEY": {"S": f"Player#{lc.player}"},
                "SKEY": {"S": f"LevelId={lc.level_id}"},
            },
            UpdateExpression=(
                "SET UpdateTime = :datetime, MoveCount = :move_count, MoveHistory = :move_history"
            ),
            ConditionExpression="MoveCount > :move_count",
            ExpressionAttributeValues={
                ":move_count": {"N": str(lc.move_count)},
                ":move_history": {"S": lc.move_history},
                ":datetime": {"S": lc.update_time},
            },
            ReturnValues="ALL_NEW",
            ReturnValuesOnConditionCheckFailure="ALL_OLD"
        )
        logger.info(f"Updated player score")
    except ClientError as e:
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            if "Item" in e.response:
                logger.info("Did not improve player score")
            else:
                logger.info("No entry exists yet")
                put_player_score(lc)
        else:
            logger.error("Failed to update player score: ", e)
            raise


def put_hof_entry(table_id: str, skey: str, lc: LevelCompletion):
    """
    Adds initial entry to given Hall of Fame
    """
    logger.info(f"Adding new entry: {table_id=}, {skey=}")
    try:
        item = {
            "PKEY": {"S": f"HallOfFame#{table_id}"},
            "SKEY": {"S": skey},
            "Player": {"S": lc.player},
            "UpdateTime": {"S": lc.update_time},
            "MoveCount": {"N": str(lc.move_count)},
            "MoveHistory": {"S": lc.move_history},
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


def try_update_hof_entry(table_id: str, skey: str, lc: LevelCompletion):
    """
    Tries to update entry for given Hall of Fame.
    Creates entry when one did not exist yet.
    Returns item for resulting entry.
    The "improved" field indicates whether score was improved.
    """
    try:
        logger.info(f"Conditionally updating HOF entry for {table_id=}, {skey=}")
        response = client.update_item(
            TableName=TABLE_NAME,
            Key={
                "PKEY": {"S": f"HallOfFame#{table_id}"},
                "SKEY": {"S": skey},
            },
            UpdateExpression=(
                "SET Player = :player, UpdateTime = :datetime, "
                "MoveCount = :move_count, MoveHistory = :move_history"
            ),
            ConditionExpression="MoveCount > :move_count",
            ExpressionAttributeValues={
                ":move_count": {"N": str(lc.move_count)},
                ":move_history": {"S": lc.move_history},
                ":datetime": {"S": lc.update_time},
                ":player": {"S": lc.player},
            },
            ReturnValues="ALL_NEW",
            ReturnValuesOnConditionCheckFailure="ALL_OLD"
        )
        logger.info(f"Updated HOF entry: {response=}")
        item = response["Attributes"]

        logger.info(f"Improved hi-score")
        item["Improved"] = True
    except ClientError as e:
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            if "Item" in e.response:
                logger.info("Did not improve existing entry")
                item = e.response["Item"]
                item["Improved"] = False
            else:
                logger.info("No entry exists yet")
                item = put_hof_entry(table_id, skey, lc)
                item["Improved"] = True
        else:
            logger.error("Failed to update hi-score: ", e)
            raise

    return item


def try_update_hof_entries(table_id: str, lc: LevelCompletion):
    # Old storage (temporary - during transition)
    skey = f"Level={lc.level}"
    item = try_update_hof_entry(table_id, skey, lc)
    if item["Improved"] and table_id != DEFAULT_TABLE_ID:
        try_update_hof_entry(DEFAULT_TABLE_ID, skey, lc)

    if lc.level_id is not None:
        # New storage
        skey = f"LevelId={lc.level_id}"
        item = try_update_hof_entry(table_id, skey, lc)
        if item["Improved"] and table_id != DEFAULT_TABLE_ID:
            try_update_hof_entry(DEFAULT_TABLE_ID, skey, lc)

    return item


def store_log_entry(lc: LevelCompletion, table_id: str):
    logger.info(f"Storing log entry {lc} for {table_id=}")

    client.put_item(
        TableName=TABLE_NAME,
        Item={
            "PKEY": {"S": f"Log#{lc.date_str}"},
            "SKEY": {"S": f"EntryTime={lc.update_time}"},
            "Player": {"S": lc.player},
            "Level": {"N": str(lc.level)},
            "LevelId": {"N": str(lc.level_id)},
            "MoveCount": {"N": str(lc.move_count)},
            "MoveHistory": {"S": lc.move_history},
            "Table": {"S": table_id},
        },
        ConditionExpression="attribute_not_exists(PKEY)"
    )

    logger.info("Stored log entry")


def handle_level_completion_post(event, context):
    request_json = json.loads(event["body"])
    try:
        level_completion = LevelCompletion.from_json(request_json)
        table_id = request_json.get("tableId", DEFAULT_TABLE_ID)
    except KeyError as e:
        return bad_request(f"Missing key: {str(e)}")
    except ValueError as e:
        return bad_request(str(e))

    try:
        store_log_entry(level_completion, table_id)
    except ClientError as e:
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            logger.warning(f"Failed to add log-entry due to clash")
            return service_unavailable()
        else:
            logger.warning(str(e))
            return server_error(str(e))

    try:
        item = try_update_hof_entries(table_id, level_completion)

        try_update_player_score(level_completion)
    except ClientError as e:
        logger.warning(str(e))
        return server_error(str(e))

    return request_handled({
        "level": level_completion.level,
        "levelId": level_completion.level_id,
        "player": item["Player"]["S"],
        "moveCount": int(item["MoveCount"]["N"]),
        "improved": item["Improved"]
    })


def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    if method == "POST":
        return handle_level_completion_post(event, context)
    elif method == "OPTIONS":
        return request_handled()

    logger.error(f"Unsupported event: {event}")
    return bad_request()
