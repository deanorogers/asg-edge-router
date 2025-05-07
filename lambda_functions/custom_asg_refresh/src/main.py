import boto3
import os
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Read ASG name from environment variable
ASG_NAME = os.getenv('ASG_NAME')
MIN_HEALTHY_PERCENT = 80
INSTANCE_WARM_UP_SEC = 5
LC_HOOK_NAME = 'smoke-test-lc-hook'

asg_client = None

def salutation(greeting):
    return greeting + ", World"

def s3_names():
    s3_client = boto3.client(
        service_name='s3',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-west-2',
        endpoint_url='http://localhost:4566',
    )
    s3_client.download_file("my-test-bucket", "names", "names_download")
    logger.info("Downloaded file")


def initialize_asg_client():
    global asg_client
    if asg_client is None:
        logger.info("Fetching boto3 asg client")
        curr_session = boto3.session.Session()
        region = curr_session.region_name
        asg_client = boto3.client(service_name='autoscaling', region_name=region)
        logger.info("Fetched asg client")

class InvalidActionError (Exception):
    pass

def handler(event, context):

    action = event['action']

    MIN_HEALTHY_PERCENT = int(os.getenv('MIN_HEALTHY_PERCENT'))
    INSTANCE_WARM_UP_SEC = int(os.getenv('INSTANCE_WARM_UP_SEC'))

    try:

        initialize_asg_client()

        if not ASG_NAME:
            raise ValueError("Environment variable ASG_NAME is not set")

        logger.info(f"Entered main function with action {action}")
        if action == "commence":
            commence_refresh()
        elif action == "continue":
            continue_refresh()
        elif action== "cancel":
            rollback_refresh()
        else:
            raise InvalidActionError(f"Invalid Action {action}")
            # raise ValueError(f"Invalid action: {action}")

    except InvalidActionError as e:
        logger.error(f"InvalidActionError: {e}")
        raise InvalidActionError(e)
        # return {
        #     "statusCode": 200,
        #     "body": str(e),
        #     "headers": {
        #         "Content-Type": "application/json"
        #     }
        # }

    except Exception as e:
        logger.error(f"Caught exception: {e}")
        return {
            "statusCode": 500,
            "body": "Internal Server Error",
            "headers": {
                "Content-Type": "application/json"
            }
        }

    return {
        "statusCode": 200
    }


# define LAUNCH life-cycle hook to pause the creation of the test instance(s), with default ABANDON
# increase ASG number by n to trigger the launch of test instance(s)
def commence_refresh ():

    logger.info("Defining LC hook")
    # define life-cycle hook that pauses the refresh until continue or cancel trigger
    response = asg_client.put_lifecycle_hook(
        LifecycleHookName=LC_HOOK_NAME,
        AutoScalingGroupName=ASG_NAME,
        LifecycleTransition='autoscaling:EC2_INSTANCE_LAUNCHING',
        DefaultResult='ABANDON'
    )

    response = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[ASG_NAME])
    asg = response['AutoScalingGroups'][0]
    current_desired = asg['DesiredCapacity']
    # current_min = asg['MinSize']
    current_max = asg['MaxSize']
    new_desired = current_desired + 1
    # new_min = max(current_min, new_desired)
    # new_max = max(current_max, new_desired)
    new_max = current_max + 1
    logger.info(f"Increasing desired capacity from {current_desired} to {new_desired}")
    asg_client.update_auto_scaling_group(
        AutoScalingGroupName=ASG_NAME,
        DesiredCapacity=new_desired,
        # MinSize=new_min,
        MaxSize=new_max
    )


# CONTINUE the LC hook for that test instance
# delete the LC hook
# decrease the ASG number by 1
# trigger refresh
def continue_refresh ():
    logger.info("Continuing refresh")

    # obtain a list of instances in pending state
    pending_instances = get_instances_by_lifecycle_state(ASG_NAME, 'Pending:Wait')
    if pending_instances == []:
        raise ValueError(f"No pending instances found")

    # continue life-cycle
    for instance_id in pending_instances:
        logger.info(f"About to continue instance: {instance_id}")
        asg_client.complete_lifecycle_action(
            AutoScalingGroupName=ASG_NAME,
            LifecycleHookName=LC_HOOK_NAME,
            LifecycleActionResult='CONTINUE',
            InstanceId=instance_id)

    # remove LC hook
    response = asg_client.delete_lifecycle_hook(
        LifecycleHookName=LC_HOOK_NAME,
        AutoScalingGroupName=ASG_NAME
    )

    # decrease the ASG nbr
    response = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[ASG_NAME])
    asg = response['AutoScalingGroups'][0]
    current_desired = asg['DesiredCapacity']
    # current_min = asg['MinSize']
    current_max = asg['MaxSize']
    new_desired = current_desired - 1
    # new_min = min(current_min, new_desired)
    # new_max = min(current_max, new_desired)
    new_max = current_max -1
    logger.info(f"Resetting desired capacity from {current_desired} to {new_desired}")
    asg_client.update_auto_scaling_group(
        AutoScalingGroupName=ASG_NAME,
        DesiredCapacity=new_desired,
        # MinSize=new_min,
        MaxSize=new_max
    )

    logger.info("Commencing refresh")
    # start refresh
    # response = asg_client.start_instance_refresh(
    #     AutoScalingGroupName=ASG_NAME,
    #     Preferences={
    #         'MinHealthyPercentage': MIN_HEALTHY_PERCENT,
    #         'InstanceWarmup': INSTANCE_WARM_UP_SEC
    #     }
    # )
    # logger.info(f"Instance Refresh Started: {json.dumps(response, indent=2)}")


# ABANDON the test instance
# decrease the ASG number by 1
# delete the LC hook
def rollback_refresh ():
    logger.info("Cancelling refresh")

    # obtain a list of instances in pending state
    pending_instances = get_instances_by_lifecycle_state(ASG_NAME, 'Pending:Wait')
    if pending_instances == []:
        raise ValueError(f"No pending instances found")

    # abandon life-cycle for pending instance(s)
    for instance_id in pending_instances:
        logger.info(f"About to rollback pending instance: {instance_id}")
        asg_client.complete_lifecycle_action(
            AutoScalingGroupName=ASG_NAME,
            LifecycleHookName=LC_HOOK_NAME,
            LifecycleActionResult='ABANDON',
            InstanceId=instance_id)

    # decrease the ASG number by 1
    response = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[ASG_NAME])
    asg = response['AutoScalingGroups'][0]
    current_desired = asg['DesiredCapacity']
    current_min = asg['MinSize']
    current_max = asg['MaxSize']
    new_desired = current_desired - 1
    new_min = min(current_min, new_desired)
    new_max = min(current_max, new_desired)
    logger.info(f"Resetting desired capacity from {current_desired} to {new_desired}")
    asg_client.update_auto_scaling_group(
        AutoScalingGroupName=ASG_NAME,
        DesiredCapacity=new_desired,
        MinSize=new_min,
        MaxSize=new_max
    )

    # remove LC hook
    response = asg_client.delete_lifecycle_hook(
        LifecycleHookName=LC_HOOK_NAME,
        AutoScalingGroupName=ASG_NAME
    )

    # asg_client.cancel_instance_refresh(
    #     AutoScalingGroupName=ASG_NAME
    # )

def get_instances_by_lifecycle_state(asg_name, lifecycle_state):
    try:
        logger.info(f"Getting instances with lifecycle state '{lifecycle_state}' for ASG '{asg_name}'")
        response = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])
        asg = response['AutoScalingGroups'][0]

        matching_instances = [
            instance['InstanceId']
            for instance in asg['Instances']
            if instance.get('LifecycleState') == lifecycle_state
        ]

        logger.info(f"Found {len(matching_instances)} instance(s) in state '{lifecycle_state}' for ASG '{asg_name}'")
        return matching_instances

    except Exception as e:
        logger.error(f"Error fetching instances in state '{lifecycle_state}' for ASG '{asg_name}': {e}")
        return []
