FROM python:3

WORKDIR /usr/backend/src

RUN pip install --no-cache-dir \
    boto3 \
    flask \
    flask-cors \
    python-lambda-local \
    setuptools

#CMD [ "bash" ]
CMD [ "flask", "run", "--host", "0.0.0.0", "--debug" ]