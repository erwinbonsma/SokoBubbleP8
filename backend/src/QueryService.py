import logging

from common import (
    bad_request,
    check_table_id,
    request_handled,
    server_error,
    DEFAULT_TABLE_ID
)
from database import DatabaseError, get_best_level_scores, get_player_scores, get_total_scores


logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handle_hof_query(table_id):
    try:
        best_level_scores = get_best_level_scores(table_id)

        total_scores = get_total_scores(table_id)
        total_scores.sort(
            key=lambda x: (x["moveTotal"], x["updateTime"])
        )
    except DatabaseError as e:
        return server_error(str(e))

    return request_handled({
        "levelScores": best_level_scores,
        "totalScores": total_scores[:10],
    })


def handle_player_query(table_id, player):
    try:
        player_scores = get_player_scores(table_id, player)
    except DatabaseError as e:
        return server_error(str(e))

    return request_handled({
        "playerLevelScores": player_scores
    })


def handle_query_get(event, context):
    params = event.get("queryStringParameters", {})
    table_id = check_table_id(params.get("id", DEFAULT_TABLE_ID))
    player = params.get("name", None)

    if player is None:
        return handle_hof_query(table_id)
    else:
        return handle_player_query(table_id, player)


def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    if method == "GET":
        return handle_query_get(event, context)
    elif method == "OPTIONS":
        return request_handled()

    logger.error(f"Unsupported event: {event}")
    return bad_request()
