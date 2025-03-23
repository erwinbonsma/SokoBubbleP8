import json
import logging

from common import (
    LEVEL_MAPPING,
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
    calculate_player_total,
    store_log_entry,
    try_update_hof_entry,
    try_update_player_score,
    update_player_total,
)

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def try_update_hof_entries(table_id: str, lc: LevelCompletion):
    item = try_update_hof_entry(table_id, lc)
    if item["Improved"] and table_id != DEFAULT_TABLE_ID:
        try_update_hof_entry(DEFAULT_TABLE_ID, lc)

    return item


def try_update_player_scores(table_id: str, lc: LevelCompletion):
    improvement = try_update_player_score(table_id, lc)
    if improvement > 0 and table_id != DEFAULT_TABLE_ID:
        try_update_player_score(DEFAULT_TABLE_ID, lc)

    return improvement


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
        response = {
            "level": level_completion.level,
            "levelId": level_completion.level_id,
            "levelRecord": {
                "player": item["Player"]["S"],
                "moveCount": int(item["MoveCount"]["N"]),
                "updated": item["Improved"]
            },
        }

        improvement = try_update_player_scores(table_id, level_completion)

        if improvement > 0:
            total = calculate_player_total(table_id, level_completion.player)
            update_player_total(
                table_id, level_completion.player, level_completion.update_time, total
            )
            response["moveTotal"] = total
    except DatabaseError as e:
        return server_error(str(e))

    return request_handled(response)


def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    if method == "POST":
        return handle_level_completion_post(event, context)
    elif method == "OPTIONS":
        return request_handled()

    logger.error(f"Unsupported event: {event}")
    return bad_request()
