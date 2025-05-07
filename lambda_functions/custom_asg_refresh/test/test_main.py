from custom_asg_refresh.src.main import salutation, s3_names
import os
import pytest
import boto3

@pytest.fixture(autouse=True)
def set_env_vars():
    os.environ['MIN_HEALTHY_PERCENT'] = '80'
    os.environ['INSTANCE_WARM_UP_SEC'] = '10'

def test_salutation():
    greeting = salutation("Hello")
    assert greeting == "Hello, World"

def test_simple_s3():

  ####### given #######
  s3 = boto3.client(
      service_name='s3',
      aws_access_key_id='test',
      aws_secret_access_key='test',
      region_name='us-west-2',
      endpoint_url='http://localhost:4566',
  )
  try:
    s3.create_bucket(Bucket="my-test-bucket", CreateBucketConfiguration={'LocationConstraint': 'us-west-2'})
  except Exception as e:
      print(f"Bucket already created error {e}")

  file_path = os.path.join(os.path.dirname(__file__), "names.txt")
  s3.upload_file(file_path, "my-test-bucket", "names")

  ####### when #######
  ## function under test will download the file in the bucket
  ## and store in names_download file
  s3_names()

  ####### then #######
  download_file_path = os.path.join(os.path.dirname(__file__), "names_download")
  try:
      with open(download_file_path, 'r') as file:
          content = file.read()
          assert "deano" in content
  except FileNotFoundError:
      print("The file names_downloaded does not exist")


def test_start_instance_refresh ():

    ####### given #######
    autoscaling_client = boto3.client(
        service_name='autoscaling',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-west-2',
        endpoint_url='http://localhost:4566',
    )
    ec2_client = boto3.client(
        service_name='ec2',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-west-2',
        endpoint_url='http://localhost:4566',
    )
    setup_autoscaling_group(autoscaling_client, ec2_client)


def setup_autoscaling_group (autoscaling_client, ec2_client):

    # create VPC and Subnet
    vpc = ec2_client.create_vpc(CidrBlock="10.0.0.0/16")
    subnet = ec2_client.create_subnet(CidrBlock="10.0.1.0/24", VpcId=vpc["Vpc"]["VpcId"])

    # create launch config
    autoscaling_client.create_launch_configuration(
        LaunchConfigurationName="test-launch-config",
        ImageId="ami-12345678",
        InstanceType="t2.micro"
    )