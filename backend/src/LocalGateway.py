from flask import Flask, request, Response
from flask.logging import default_handler
from flask_cors import CORS

import json
import logging

from HallOfFameService import handle_hall_of_fame_get
from LevelCompletionService import handle_level_completion_post
from QueryService import handle_query_get
from migrate.CopyOldHofEntries import copy_old_hof_entries
from migrate.PopulatePlayerScores import populate_player_scores
from migrate.UpdateTotals import update_totals

app = Flask(__name__)
CORS(app)
app.logger.setLevel(logging.INFO)

for logger_name in [
    app.name,
    "common",
    "database",
    "HallOfFameService",
    "LevelCompletionService",
    "QueryService",
    "migrate.CopyOldHofEntries",
    "migrate.PopulatePlayerScores",
    "migrate.UpdateTotals",
]:
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


@app.route('/scores', methods=['GET'])
def get_scores():
    return convert_response(handle_query_get({
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


@app.route('/migrate/copy_old_hof_entries', methods=['POST'])
def wrap_copy_old_hof_entries():
    return convert_response(copy_old_hof_entries({
        "queryStringParameters": request.args
    }, None))


@app.route('/migrate/populate_player_scores', methods=['POST'])
def wrap_populate_player_scores():
    return convert_response(populate_player_scores({
        "queryStringParameters": request.args
    }, None))


@app.route('/migrate/update_totals', methods=['POST'])
def wrap_update_totals():
    return convert_response(update_totals({
        "queryStringParameters": request.args
    }, None))

# if __name__ == '__main__':
#    app.run(debug=True, port=5000)
