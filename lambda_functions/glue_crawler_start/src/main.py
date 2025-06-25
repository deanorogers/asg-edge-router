
import boto3
import logging
import os
# from concurrent.futures import ThreadPoolExecutor

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

glue_client = None

def initialize_athena_client():
    global glue_client
    if glue_client is None:
        logger.info("Fetching boto3 glue client")
        curr_session = boto3.session.Session()
        region = curr_session.region_name
        glue_client = boto3.client(service_name='glue', region_name=region)
        logger.info("Fetched glue client")

def start_crawler ():

    CRAWLER_NAME = os.getenv('CRAWLER_NAME')

    logger.info(f"Starting crawler {CRAWLER_NAME}")

    try:
        response = glue_client.start_crawler(Name=CRAWLER_NAME)
        statusCode = response['ResponseMetadata']['HTTPStatusCode']
        logger.info (f"Gotten response status {statusCode} from crawler")
        return statusCode
    except Exception as e:
        logger.error(f"Error: {e}")
        return {
            "statusCode": 500,
            "body": e
        }

def handler(event, context):

  initialize_athena_client()
  statusCode = start_crawler()

  return {
      "statusCode": statusCode
  }
  # Run asynchronously
  # executor = ThreadPoolExecutor(max_workers=1)
  # executor.submit(start_crawler)


