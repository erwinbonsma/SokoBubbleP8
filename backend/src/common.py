import json

DEFAULT_TABLE_ID = "global"


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
