import boto3
# import os
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

def handler(event, context):

    try:

        logger.info("Fetching boto3 client")
        curr_session = boto3.session.Session()
        region = curr_session.region_name
        ec2_client = boto3.client(service_name='ec2', region_name=region)
        logger.info("Fetched ec2 client")

        logger.info("Getting input values")

        lt_id = event.get('lt_id')
        lt_base_version = event.get('lt_base_version')

        logger.info("Checking input params")

        if 'lt_id' not in event or event['lt_id'] is None:
          raise ValueError("Missing or null 'lt_id'")

        if 'lt_base_version' not in event or event['lt_base_version'] is None:
            raise ValueError("Missing or null 'lt_base_version'")

        logger.info(f"input parameters OK: {lt_id}, {lt_base_version}")

        response = ec2_client.create_launch_template_version(
            LaunchTemplateId=lt_id,
            SourceVersion=lt_base_version,
            VersionDescription=f'Created by lambda function to rollback launch template',
            LaunchTemplateData={}
        )
        logger.info(f"Response: {response}")

        return {
            "statusCode": 200
        }

    except Exception as e:
        logger.error(f"Caught exception: {e}")
        return {
            "statusCode": 500,
            "body": "Internal Server Error",
            "headers": {
                "Content-Type": "application/json"
            }
        }

