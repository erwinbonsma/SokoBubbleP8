#!/bin/sh

echo "Waiting for DynamoDB to start up"
sleep 4

echo "Creating tables"
DYNAMODB_CMD="aws dynamodb --endpoint-url ${DYNAMODB_ENDPOINT} --region ${AWS_DEFAULT_REGION}"
TABLE_NAME="Sokobubble-dev"

${DYNAMODB_CMD} create-table \
	--table-name ${TABLE_NAME} \
	--attribute-definitions AttributeName=PKEY,AttributeType=S AttributeName=SKEY,AttributeType=S \
	--key-schema AttributeName=PKEY,KeyType=HASH AttributeName=SKEY,KeyType=RANGE \
	--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

echo "Done"

# Sleep so that container can be used to interactively inspect tables
sleep 2147483647