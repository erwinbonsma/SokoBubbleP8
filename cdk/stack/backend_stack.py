import os
from aws_cdk import (
    CfnOutput,
    Stack,
    aws_dynamodb as dynamodb,
    aws_lambda as _lambda
)
from constructs import Construct

STAGE = os.environ.get("STAGE", "dev")


class BackendStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        main_table = dynamodb.Table(
            self, "MainTable",
            table_name=f"Sokobubble-{STAGE}",
            partition_key=dynamodb.Attribute(
                name="PKEY",
                type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="SKEY",
                type=dynamodb.AttributeType.STRING
            ),
        )

        shared_lambda_cfg = {
            "runtime": _lambda.Runtime.PYTHON_3_12
        }

        log_completion_handler = _lambda.Function(
            self, 'LevelCompletionService',
            **shared_lambda_cfg,
            code=_lambda.Code.from_asset('../backend/src'),
            handler='LevelCompletionService.handler',
        )
        main_table.grant_read_write_data(log_completion_handler)

        hall_of_fame_handler = _lambda.Function(
            self, 'HallOfFameService',
            **shared_lambda_cfg,
            code=_lambda.Code.from_asset('../backend/src'),
            handler='HallOfFameService.handler',
        )
        main_table.grant_read_data(hall_of_fame_handler)

        log_completion_url = log_completion_handler.add_function_url(
            auth_type=_lambda.FunctionUrlAuthType.NONE
        )
        hall_of_fame_url = hall_of_fame_handler.add_function_url(
            auth_type=_lambda.FunctionUrlAuthType.NONE
        )

        CfnOutput(self, 'LogCompletionLambdaURL', value=log_completion_url.url)
        CfnOutput(self, 'HallOfFameLambdaURL', value=hall_of_fame_url.url)
