import logging

from common import (
    DEFAULT_TABLE_ID,
    LEVEL_MAPPING_VERSION,
    request_handled,
    server_error,
)
from database import (
    DatabaseError,
    calculate_player_total,
    get_total_scores,
    update_player_total
)


logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def update_totals(event, context):
    params = event.get("queryStringParameters", {})
    table_id = params.get("id", DEFAULT_TABLE_ID)
    old_mapping_version = params.get("old_version", LEVEL_MAPPING_VERSION - 1)

    updates = []
    try:
        old_totals = get_total_scores(table_id, old_mapping_version)
        for entry in old_totals:
            player = entry["player"]
            update_time = entry["updateTime"]
            old_total = entry["moveTotal"]

            new_total = calculate_player_total(table_id, player)
            logger.info(f"Updating total for {player} from {old_total} to {new_total}")
            update_player_total(table_id, player, update_time, new_total)

            updates.append({
                "player": player,
                "oldTotal": old_total,
                "newTotal": new_total,
            })
    except DatabaseError as e:
        return server_error(str(e))

    return request_handled(updates)
