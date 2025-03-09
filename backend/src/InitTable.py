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


def _put_initial_hof_entry(level, force=False):
    client.put_item(
        TableName=table_name,
        Item={
            "PKEY": {"S": "HallOfFame"},
            "SKEY": {"S": f"Level={level}"},
            "Player": {"S": "-"},
            "MoveCount": {"N": "999"},
        },
        ConditionExpression=None if force else "attribute_not_exists(PKEY)"
    )


def handle_populate_hof_table(event, context):
    for i in range(24):
        _put_initial_hof_entry(i + 1)
