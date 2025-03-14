from flask import Flask, request, Response
from flask.logging import default_handler
from flask_cors import CORS

import json
import logging

from HallOfFameService import handle_hall_of_fame_get
from LevelCompletionService import handle_level_completion_post

app = Flask(__name__)
CORS(app)
app.logger.setLevel(logging.INFO)

for logger_name in [app.name, "HallOfFameService", "LevelCompletionService"]:
    logger = logging.getLogger(logger_name)
    logger.addHandler(default_handler)


def convert_response(response):
    return Response(
        response["body"],
        status=response["statusCode"],
        mimetype=response["headers"]["Content-Type"]
    )


@app.route('/hall_of_fame', methods=['GET'])
def get_hall_of_fame():
    return convert_response(handle_hall_of_fame_get({
        "queryStringParameters": request.args
    }, None))


@app.route('/level_completion', methods=['POST'])
def post_level_completion():
    print(request)
    print(request.json)
    try:
        return convert_response(handle_level_completion_post({
            "body": json.dumps(request.json)
        }, None))
    except Exception as e:
        print("Error", e)


# if __name__ == '__main__':
#    app.run(debug=True, port=5000)
