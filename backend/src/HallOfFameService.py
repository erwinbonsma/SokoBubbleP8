import logging

from common import (
    bad_request,
    check_table_id,
    request_handled,
    server_error,
    DEFAULT_TABLE_ID
)
from database import DatabaseError, get_best_level_scores, get_total_scores


logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handle_hall_of_fame_get(event, context):
    params = event.get("queryStringParameters", {})
    table_id = check_table_id(params.get("id", DEFAULT_TABLE_ID))
    key = params.get("key", "index")

    logger.info(f"Request for Hall of Fame {id=}, {key=}")
    if key == "index":
        skey = "Level="
    elif key == "id":
        skey = "LevelId="
    else:
        return bad_request(f"Unknown key '{key}'")

    try:
        best_level_scores = get_best_level_scores(table_id, skey)

        total_scores = get_total_scores(table_id)
        total_scores.sort(
            key=lambda x: (x["moveTotal"], x["updateTime"])
        )
    except DatabaseError as e:
        return server_error(str(e))

    return request_handled({
        "hallOfFame": best_level_scores,
        "totalScores": total_scores[:10],
    })


def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    if method == "GET":
        return handle_hall_of_fame_get(event, context)
    elif method == "OPTIONS":
        return request_handled()

    logger.error(f"Unsupported event: {event}")
    return bad_request()
