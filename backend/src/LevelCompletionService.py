import json
import logging

from common import (
    bad_request,
    check_table_id,
    request_handled,
    server_error,
    service_unavailable,
    DEFAULT_TABLE_ID,
    LevelCompletion,
)
from database import (
    DatabaseError,
    store_log_entry,
    try_update_hof_entry,
    try_update_player_score,
)

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


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


def handle_level_completion_post(event, context):
    request_json = json.loads(event["body"])
    try:
        level_completion = LevelCompletion.from_json(request_json)
        table_id = check_table_id(request_json.get("tableId", DEFAULT_TABLE_ID))
    except KeyError as e:
        return bad_request(f"Missing key: {str(e)}")
    except ValueError as e:
        return bad_request(str(e))

    try:
        if not store_log_entry(level_completion, table_id):
            logger.warning(f"Failed to add log-entry due to clash")
            return service_unavailable()
    except DatabaseError as e:
        return server_error(str(e))

    try:
        item = try_update_hof_entries(table_id, level_completion)

        try_update_player_score(table_id, level_completion)
    except DatabaseError as e:
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
