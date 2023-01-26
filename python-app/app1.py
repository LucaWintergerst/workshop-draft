import boto3
from botocore.exceptions import ClientError
from flask import Flask
from flask import request

import os
from dotenv import load_dotenv

import random
import time
import requests

import logging
import ecs_logging
import structlog

load_dotenv()

from collections import deque

# disable the default flask logger
logger = logging.getLogger('werkzeug')
logger.setLevel(logging.DEBUG)

logger = logging.getLogger("app")
logger.setLevel(logging.DEBUG)

# Log to a file
handler = logging.FileHandler(filename='/tmp/service1.log')
handler.setFormatter(ecs_logging.StdlibFormatter())

logger.addHandler(handler)

from elasticapm.handlers.structlog import structlog_processor
structlog.configure(
    processors=[structlog_processor,ecs_logging.StructlogFormatter()],
    wrapper_class=structlog.BoundLogger,
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory()
)

app = Flask(__name__)

app.logger.addHandler(handler)

# instrument flask with Elastic APM
from elasticapm.contrib.flask import ElasticAPM
import elasticapm

app.config['ELASTIC_APM'] = {
    'SERVER_URL': os.environ["SERVER_URL"],
    'SERVICE_NAME': os.environ["SERVICE_NAME"],
    'SECRET_TOKEN': os.environ["SECRET_TOKEN"],
    'ENVIRONMENT':  'dev'
}
apm = ElasticAPM(app)

dynamodb = boto3.client("dynamodb", region_name='us-east-1', aws_access_key_id= os.environ["aws_access_key_id"], aws_secret_access_key= os.environ["aws_secret_access_key"])

try:
  response = dynamodb.create_table(
    TableName="app1-items-table",
    AttributeDefinitions=[
      {
        "AttributeName": "item",
        "AttributeType": "S"
      },
      {
        "AttributeName": "id",
        "AttributeType": "S"
      }
    ],
    KeySchema=[
      {
        "AttributeName": "item",
        "KeyType": "HASH"
      },
      {
        "AttributeName": "id",
        "KeyType": "RANGE"
      }
    ],
    ProvisionedThroughput={
      "ReadCapacityUnits": 1,
      "WriteCapacityUnits": 1
    }
  )
except ClientError as err:
  print(err)

lambdaClient = boto3.client('lambda', region_name='us-east-1', aws_access_key_id=os.environ["aws_access_key_id"], aws_secret_access_key=os.environ["aws_secret_access_key"])


@app.route("/add-item", methods=["POST"])
def endpoint1():
    logger.info("Received request", extra={"client.ip": request.headers['X-Real-IP']})
    req = request.get_json()
    item = req.get("item")
    dyanmoItem = None
    if ("item" in req):
        item = req.get("item")
        metadata = "" 
        if (random.random() > 0.5):
          if not ("metadata" in item):
            logger.info("item %s needs enrichment", item)            
            load_dotenv(override=True)
            metadata = requests.get(os.environ["aws_lambda_url"]).json()['message']
            #logger.error("The lambda function defined in the .env file within the app directory seems to be wrong. Change it!")  
            
            #We add the enrichment label only if the enrichment was successful.
            elasticapm.label(enrichment=True)
          else: 
            metadata = req.get("item").get("metadata")
        dyanmoItem = {
          'id': {'S': str(req.get("id")), },
          'item': {'S': req.get("item").get("name"), },
          'metadata': {'S': metadata,},
        }
    response = dynamodb.put_item(
      TableName='app1-items',
      Item=dyanmoItem
    )
    return "success"

app.run(host='0.0.0.0', port=5002)
