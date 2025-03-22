from dataclasses import dataclass
import datetime
import itertools
import json
from typing import Optional

DEFAULT_TABLE_ID = "global"

NUM_LEVELS = 24
MIN_MOVE_COUNT = 20
MAX_MOVE_COUNT = 999

MAX_TABLE_ID_LEN = 8

LEVEL_ID_SET_VERSION = 1
LEVEL_ID_SET = [
    1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 26
]

VALID_ID_CHARS = set(
    itertools.chain(
        (chr(ord('a') + i) for i in range(26)),
        (chr(ord('A') + i) for i in range(26)),
        (chr(ord('0') + i) for i in range(10)),
        "-_"
    )
)


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


def check_id(s, max_len):
    """
    >>> check_id("abcd", 6)
    'abcd'

    >>> check_id("abcdefgh", 6)
    Traceback (most recent call last):
       ...
    ValueError: ID is too long

    >>> check_id("1+2", 6)
    Traceback (most recent call last):
       ...
    ValueError: Invalid characters

    """
    if len(s) > max_len:
        raise ValueError("ID is too long")
    if len(set(s).difference(VALID_ID_CHARS)) > 0:
        raise ValueError("Invalid characters")
    return s


def check_table_id(table_id):
    return check_id(table_id, MAX_TABLE_ID_LEN)


if __name__ == '__main__':
    import doctest
    doctest.testmod()
