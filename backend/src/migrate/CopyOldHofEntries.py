import logging
import os

import boto3
from botocore.exceptions import ClientError

from common import (
    DEFAULT_TABLE_ID,
    LevelCompletion,
    bad_request,
    request_handled,
    server_error
)
from LevelCompletionService import try_update_hof_entry

STAGE = os.environ.get("STAGE", "dev")
TABLE_NAME = f"Sokobubble-{STAGE}"

client = boto3.client("dynamodb", endpoint_url=os.environ.get("DYNAMODB_ENDPOINT"))
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Conversion from Level Index to level ID (at v1.0, when HOF entries were only
# stored by Level Index)
LEVEL_IDX_MAP = {
    1: 1,
    2: 2,
    3: 3,
    4: 4,
    5: 6,
    6: 7,
    7: 24,
    8: 8,
    9: 9,
    10: 16,
    11: 17,
    12: 21,
    13: 23,
    14: 10,
    15: 11,
    16: 15,
    17: 12,
    18: 14,
    19: 20,
    20: 26,
    21: 13,
    22: 18,
    23: 19,
    24: 22,
}


def copy_old_hof_entries(event, context):
    table_id = event.get("queryStringParameters", {}).get("id", DEFAULT_TABLE_ID)
    logger.info(f"Converting entries for Hall of Fame {table_id=}")

    try:
        response = client.query(
            TableName=TABLE_NAME,
            KeyConditionExpression="PKEY = :pkey AND begins_with(SKEY, :skey_prefix)",
            ExpressionAttributeValues={
                ":pkey": {"S": f"HallOfFame#{table_id}"},
                ":skey_prefix": {"S": "Level="}
            }
        )
        logger.debug(f"{response=}")
    except ClientError as e:
        logger.warning(str(e))
        return server_error(str(e))

    for item in response["Items"]:
        logger.info(item)

        level_index = int(item["SKEY"]["S"][6:])
        if "MoveHistory" in item:
            move_history = item["MoveHistory"]["S"]
        else:
            move_history = "unknown"

        level_completion = LevelCompletion(
            player=item["Player"]["S"],
            level=level_index,
            level_id=LEVEL_IDX_MAP[level_index],
            update_time=item["UpdateTime"]["S"],
            move_count=int(item["MoveCount"]["N"]),
            move_history=move_history,
        )

        logger.info(f"{level_completion}")

        try_update_hof_entry(table_id, level_completion)

    return request_handled()
