import logging
import os

import boto3
from botocore.exceptions import ClientError

from common import LevelCompletion

STAGE = os.environ.get("STAGE", "dev")
TABLE_NAME = f"Sokobubble-{STAGE}"

client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))

logger = logging.getLogger(__name__)


class DatabaseError(Exception):
    def __init__(self, message):
        self.message = message


def raise_error(msg, ex):
    logger.error(msg, ex)
    raise DatabaseError(f"{msg}: {ex}")


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
        raise_error("Failed top create initial score entry", e)


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
            raise_error("Failed to update player score", e)


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
        raise_error("Failed to create initial HOF entry", e)


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
            raise_error("Failed to update hi-score", e)

    return item


def store_log_entry(lc: LevelCompletion, table_id: str):
    logger.info(f"Storing log entry {lc} for {table_id=}")

    try:
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
    except ClientError as e:
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            logger.warning(f"Failed to add log-entry due to clash")
            return False
        else:
            raise_error("Failed to add log-entry", e)

    logger.info("Stored log entry")
    return True
