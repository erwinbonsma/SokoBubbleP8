FROM python:3

WORKDIR /usr/backend/src

RUN pip install --no-cache-dir \
    boto3 \
    flask \
    python-lambda-local \
    setuptools

#CMD [ "bash" ]
ENTRYPOINT [ "/usr/backend/scripts/entrypoint.sh" ]
CMD [ "flask", "run", "--host", "0.0.0.0" ]