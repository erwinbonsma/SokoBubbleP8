#!/bin/bash

python-lambda-local -f handle_populate_hof_table InitTable.py ../json/empty.json

exec "$@"