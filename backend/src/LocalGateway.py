from flask import Flask, request
import json

from HallOfFameService import handle_hall_of_fame_get
from LevelCompletionService import handle_level_completion_put

app = Flask(__name__)


@app.route('/hall_of_fame', methods=['GET'])
def get_hall_of_fame():
    return handle_hall_of_fame_get(None, None)


@app.route('/level_completion', methods=['PUT'])
def put_level_completion():
    print(request)
    print(request.json)
    return handle_level_completion_put({
        "body": json.dumps(request.json)
    }, None)


# if __name__ == '__main__':
#    app.run(debug=True, port=5000)
