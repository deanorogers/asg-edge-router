import boto3
# import os
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

def handler(event, context):

    logger.info("Fetching boto3 client")
    curr_session = boto3.session.Session()
    region = curr_session.region_name
    acm_client = boto3.client(service_name='acm', region_name=region)
    logger.info("Fetched acm client")

    pca_arn = event.get('certificate_authority_arn')

    response = acm_client.request_certificate(
        DomainName='test.internal.example.com',
        CertificateAuthorityArn=pca_arn,
        Tags=[
            {
                'Key': 'Name',
                'Value': 'test-from-pca'
            },
        ],
    )

    return {
        "statusCode": 200
    }


