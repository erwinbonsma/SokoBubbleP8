from LevelCompletionService import handle_level_completion_put
from common import bad_request


def handler(event, context):
    method = event["httpMethod"].upper()
    resource = event["resource"]

    if method == "PUT" and resource == "level_completion":
        return handle_level_completion_put(event, context)

    return bad_request()
