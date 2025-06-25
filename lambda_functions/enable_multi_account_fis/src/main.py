
import boto3
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

athena_client = None

def handler(event, context):
    logger.info("Starting handler for multi-account enablement of FIS")

    fis_client = boto3.client('fis')

    experiment_id = event.get("experiment_id", "")
    if not experiment_id:
        logger.error("Must specify experiment_id")
        raise ValueError("The 'experiment_id' parameter must not be empty or None.")

    accounts = event.get("target_accounts", [])
    if not accounts:
        logger.error("Must specify at least 1 target account")
        raise ValueError("The 'target_accounts' parameter must not be empty or None.")

    for account in accounts:

        response = fis_client.create_target_account_configuration(
            experimentTemplateId=experiment_id,
            accountId=account.get("accountNbr"),
            roleArn=account.get("roleArn"),
            description='Target account for Fault Injection Service'
        )

    logger.info("Updated experiment with target accounts, successfully")

