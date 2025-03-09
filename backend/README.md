# DynamoDB schema

Level Completion Logs
- PKEY = "Log"
- SKEY = "Datetime={datetime in seconds}"
    - Only one entry per second is allowed.
    - The request is rejected when item cannot be added
    - This is a simple guard against brute-force DDOS attacks
- Level = {index}
- Player = "{playername}"
- MoveCount
- MoveHistory = "{moves}"
    - E.g. "u2d3l2u2r2d3u3r2d2"

Level Hi-score
- PKEY = "HallOfFame"
- SKEY = "Level={index}"
- Player = "{playername}"
- MoveCount
- Datetime = "{datetime in seconds}"

# REST API

GET hall_of_fame
- Returns hi-score for each level

PUT level_completion
- Adds to log
    - Returns 503 (Service Unavailable) when log entry is already there
- Optionally: Verifies that move history is valid
- Conditionally updates Hi-score (on score being lower)
- Returns hi-score entry for level

# Testing

Initialize Hall of Fame:
```
python-lambda-local -f handle_populate_hof_table InitTable.py inputs/empty.json
```

Retrieve Hall of Fame:
```
python-lambda-local -f handle_hall_of_fame_get HallOfFameService.py inputs/empty.json
```

Log level completion (and optionally update Hall of Fame):
```
python-lambda-local -f handle_level_completion_put LevelCompletionService.py inputs/level-completion-level1-moves23.json
```
