import logging
import os

import boto3
from botocore.exceptions import ClientError

from common import LEVEL_ID_SET, LEVEL_ID_SET_VERSION, MAX_MOVE_COUNT, LevelCompletion

STAGE = os.environ.get("STAGE", "dev")
TABLE_NAME = f"Sokobubble-{STAGE}"

client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class DatabaseError(Exception):
    def __init__(self, message):
        self.message = message


def raise_error(msg, ex):
    logger.error(msg, ex)
    raise DatabaseError(f"{msg}: {ex}")


def calculate_player_total(table_id: str, player: str) -> int:
    skey_prefix = f"Table={table_id},"

    try:
        response = client.query(
            TableName=TABLE_NAME,
            KeyConditionExpression="PKEY = :pkey AND begins_with(SKEY, :skey_prefix)",
            ExpressionAttributeValues={
                ":pkey": {"S": f"Player#{player}"},
                ":skey_prefix": {"S": skey_prefix}
            }
        )
        logger.debug(f"{response=}")
    except ClientError as e:
        raise_error("Failed to get player scores", e)

    skey_prefix += "LevelId="
    scores = {
        int(item["SKEY"]["S"][len(skey_prefix):]): int(item["MoveCount"]["N"])
        for item in response["Items"]
    }
    logger.info(scores)

    total = sum(scores.get(level_id, MAX_MOVE_COUNT) for level_id in LEVEL_ID_SET)
    logger.info(f"Total for {player} in {table_id} is {total}")

    return total


def update_player_total(table_id: str, player: str, update_time: str, total: int):
    logger.info(f"Set player total for {player} to {total}")
    try:
        item = {
            "PKEY": {"S": f"PlayerTotal#{table_id}#{LEVEL_ID_SET_VERSION}"},
            # SKEY such that players are sorted by raking
            "SKEY": {"S": f"Total={total:06}#{update_time}"},
            "Player": {"S": player},
        }

        client.put_item(TableName=TABLE_NAME, Item=item)
    except ClientError as e:
        raise_error("Failed top update player total", e)


def put_player_score(table_id: str, lc: LevelCompletion):
    logger.info(f"Adding new player score entry")
    try:
        item = {
            "PKEY": {"S": f"Player#{lc.player}"},
            "SKEY": {"S": f"Table={table_id},LevelId={lc.level_id}"},
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


def try_update_player_score(table_id: str, lc: LevelCompletion):
    try:
        logger.info(f"Conditionally updating player score")
        response = client.update_item(
            TableName=TABLE_NAME,
            Key={
                "PKEY": {"S": f"Player#{lc.player}"},
                "SKEY": {"S": f"Table={table_id},LevelId={lc.level_id}"},
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
            ReturnValues="UPDATED_OLD",
            ReturnValuesOnConditionCheckFailure="ALL_OLD"
        )
        item = response["Attributes"]
        logger.info(item)
        improvement = int(item["MoveCount"]["N"]) - lc.move_count

        logger.info(f"Updated player score: {improvement=}")

        return improvement
    except ClientError as e:
        if e.response['Error']['Code'] == "ConditionalCheckFailedException":
            if "Item" in e.response:
                item = e.response["Item"]
                delta = int(item["MoveCount"]["N"]) - lc.move_count

                logger.info(f"Did not improve player score: {delta=}")

                return 0
            else:
                logger.info("No entry exists yet")
                put_player_score(table_id, lc)

                return MAX_MOVE_COUNT - lc.move_count
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
        item = response["Attributes"]
        logger.info(f"Updated HOF entry: {item=}")

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
