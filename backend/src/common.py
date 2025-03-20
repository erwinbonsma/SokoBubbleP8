from dataclasses import dataclass
import datetime
import json
from typing import Optional

DEFAULT_TABLE_ID = "global"

NUM_LEVELS = 24
MIN_MOVE_COUNT = 20
MAX_MOVE_COUNT = 999


@dataclass
class LevelCompletion:
    player: str
    level: int
    level_id: Optional[int]
    update_time: str
    move_count: int
    move_history: str

    def __post_init__(self):
        if (
            len(self.player) > 8
            or (self.level < 1 or self.level > NUM_LEVELS)
            or (self.move_count < MIN_MOVE_COUNT or self.move_count > MAX_MOVE_COUNT)
            or len(self.move_history) > self.move_count
        ):
            raise ValueError("Field validation failed")

    @property
    def date_str(self):
        return self.update_time[:self.update_time.find(" ")]

    @staticmethod
    def from_json(json):
        return LevelCompletion(
            player=json["player"],
            level=json["level"],
            level_id=json.get("levelId"),
            move_count=json["moveCount"],
            move_history=json["moveHistory"],
            update_time=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )


def lambda_responder(body, status_code):
    return {
        "body": json.dumps(body) if body is not None else {},
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS,GET,POST"
        }
    }


def request_handled(body=None):
    return lambda_responder(body, 200)


def bad_request(body=None):
    return lambda_responder(body, 400)


def server_error(body=None):
    return lambda_responder(body, 500)


def service_unavailable(body=None):
    return lambda_responder(body, 503)
