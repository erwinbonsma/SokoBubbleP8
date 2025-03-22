# DynamoDB schema

Level Completion Logs
- PKEY = "Log#{date}"
- SKEY = "Datetime={datetime in seconds}"
    - Only one entry per second is allowed.
    - The request is rejected when item cannot be added
    - This is a simple guard against brute-force DDOS attacks
- Level = {index}
- LevelId = {level ID}
- Player = "{playername}"
- MoveCount
- MoveHistory = "{moves}"
    - E.g. "u2d3l2u2r2d3u3r2d2"

Level Hi-score
- PKEY = "HallOfFame#{id}"
- SKEY = "LevelId={index}"
- Player = "{playername}"
- MoveCount
- MoveHistory
- UpdateTime = "{datetime in seconds}"

Player Hi-scores
- PKEY = "Player#{playername}"
- SKEY = "Table={id},LevelId={level ID}
- UpdateTime = "{datetime in seconds}"
- MoveCount
- MoveHistory = "{moves}"
    - E.g. "u2d3l2u2r2d3u3r2d2"

Player Totals
- PKEY = "PlayerTotal#{id}#{level set version}"
    - id: The table ID, allowing competition among a smaller group of players
    - level set version: Version that represents the set of level IDs that are
      summed for this total.
- SKEY = "Player={player}
    - Ensures only single entry per player
- MoveTotal = "{moves}"
- UpdateTime = "{datetime of last improvement}"

# REST API

GET hall_of_fame[?id={id}&key={index|id}]
- Returns hi-score for each level
- The optional `id` selects the table. Defaults to "global"
- The optional `key` selects the key used for the Hall of Fame entries
    - `index` is deprecated (but still the default to support old clients)
    - New clients should use `id` to support updates to levels

PUT level_completion
- Adds to log
    - Returns 503 (Service Unavailable) when log entry is already there
    - This is a simple DDOS protection mechanism
- Optionally: Verifies that move history is valid
- Conditionally updates Hi-score (on score being lower)
- Returns hi-score entry for level

# Testing

Retrieve Hall of Fame:
```
python-lambda-local -f handle_hall_of_fame_get HallOfFameService.py ../json/empty.json
```

Log level completion (and optionally update Hall of Fame):
```
python-lambda-local -f handle_level_completion_post LevelCompletionService.py ../json/level-completion-level1-moves23.json
```
