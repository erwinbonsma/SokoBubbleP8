import aws_cdk as cdk

from stack.backend_stack import BackendStack


app = cdk.App()
BackendStack(app, "Sokobubble")

app.synth()
