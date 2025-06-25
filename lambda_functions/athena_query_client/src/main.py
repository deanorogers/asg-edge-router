
import boto3
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

athena_client = None

def salutation (greeting):
    logging.info(f"{greeting}, Dean")

def initialize_athena_client():
    global athena_client
    if athena_client is None:
        logging.info("Fetching boto3 athena client")
        curr_session = boto3.session.Session()
        region = curr_session.region_name
        athena_client = boto3.client(service_name='athena', region_name=region)
        logging.info("Fetched athena client")

def start_query ():
    logging.info("Starting query")
    response = athena_client.start_query_execution(
        QueryString='SELECT * FROM "athena_alb_access_logs"."alb_logs"',
        #ClientRequestToken='d9b2d63d-a233-4123-847a-7cb2e3b9c9c1',
        QueryExecutionContext={
            'Database': 'athena_alb_access_logs',
            'Catalog': 'AwsDataCatalog'
        },
        WorkGroup='alb_logs_workgroup',
        ResultConfiguration={
            'OutputLocation': 's3://alb-access-log-results/'
        }
    )
    query_execution_id = response['QueryExecutionId']
    logging.info(f"Query Execution ID: {query_execution_id}")


initialize_athena_client()
start_query()
salutation("Hello")


