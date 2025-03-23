from collections import defaultdict
from dataclasses import dataclass
import logging
from typing import Optional

from botocore.exceptions import ClientError

from common import (
    DEFAULT_TABLE_ID,
    request_handled,
    server_error,
    LevelCompletion,
)
from database import (
    calculate_player_total,
    client,
    TABLE_NAME,
    try_update_player_score,
    update_player_total
)


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


@dataclass
class ScoreEntry:
    update_time: Optional[str] = None
    move_count: int = 1000
    move_history: Optional[str] = None
    table_id: Optional[str] = None


def get_player_scores_from_log(pkey):
    try:
        response = client.query(
            TableName=TABLE_NAME,
            KeyConditionExpression="PKEY = :pkey",
            ExpressionAttributeValues={
                ":pkey": {"S": pkey},
            }
        )
    except ClientError as e:
        logger.warning(str(e))
        return server_error(str(e))

    table: dict[str, dict[int, ScoreEntry]] = defaultdict(lambda: defaultdict(ScoreEntry))
    for item in response["Items"]:
        level_index = int(item["Level"]["N"])
        player = item["Player"]["S"]
        move_count = int(item["MoveCount"]["N"])

        ptable = table[player]
        if ptable[level_index].move_count > move_count:
            move_history = item["MoveHistory"]["S"]
            entry_time = item["SKEY"]["S"][10:]
            table_id = item["Table"]["S"]

            ptable[level_index] = ScoreEntry(
                update_time=entry_time,
                move_count=move_count,
                move_history=move_history,
                table_id=table_id,
            )

    return table


def try_update_player_scores(player: str, level_index: int, score_entry: ScoreEntry):
    level_completion = LevelCompletion(
        player=player,
        level=level_index,
        level_id=LEVEL_IDX_MAP[level_index],
        update_time=score_entry.update_time,
        move_count=score_entry.move_count,
        move_history=score_entry.move_history
    )

    if (
        try_update_player_score(score_entry.table_id, level_completion)
        and score_entry.table_id != DEFAULT_TABLE_ID
    ):
        try_update_player_score(DEFAULT_TABLE_ID, level_completion)
        return True
    else:
        return False


def populate_player_scores(event, context):
    pkey = event.get("queryStringParameters", {}).get("log_pkey", "Log")

    scores = get_player_scores_from_log(pkey)

    for player, ptable in scores.items():
        logger.info(f"{player=}")
        table_ids = {DEFAULT_TABLE_ID}
        last_update = None
        for level_index, score_entry in ptable.items():
            improved = try_update_player_scores(player, level_index, score_entry)
            logger.info(f"  {level_index=}: {score_entry} {improved=}")

            table_ids.add(score_entry.table_id)
            if last_update is None or score_entry.update_time > last_update:
                last_update = score_entry.update_time

        for table_id in table_ids:
            total = calculate_player_total(table_id, player)
            update_player_total(table_id, player, last_update, total)

    return request_handled()
