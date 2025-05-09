resource "aws_s3_bucket" "alb_access_logs_athena_results" {
  bucket = "alb-access-athena-nginx"
  acl    = "private"
}

resource "aws_athena_workgroup" "alb_logs_workgroup" {
  name = "alb_logs_workgroup"

#  configuration {
#    result_configuration {
#      output_location = "s3://${aws_s3_bucket.alb_access_logs_athena_results.bucket}/athena-results/"
#    }
#  }
  depends_on = [aws_s3_bucket.alb_access_logs_athena_results]
}

resource "aws_athena_database" "alb_access_logs" {
  name = "athena_alb_access_logs"
  bucket = aws_s3_bucket.alb_access_logs_athena_results.id
}

resource "aws_athena_named_query" "alb_access_logs" {
  name     = "alb_access_logs"
  database = aws_athena_database.alb_access_logs.name
#  bucket = aws_s3_bucket.alb_access_logs_bucket.bucket
  workgroup = aws_athena_workgroup.alb_logs_workgroup.name
  query = <<EOT
CREATE EXTERNAL TABLE IF NOT EXISTS alb_logs(
    type string,
    time string,
    elb string,
    client_ip string,
    client_port int,
    target_ip string,
    target_port int,
    request_processing_time double,
    target_processing_time double,
    response_processing_time double,
    elb_status_code int,
    target_status_code string,
    received_bytes bigint,
    sent_bytes bigint,
    request_verb string,
    request_url string,
    request_proto string,
    user_agent string,
    ssl_cipher string,
    ssl_protocol string,
    target_group_arn string,
    trace_id string,
    domain_name string,
    chosen_cert_arn string,
    matched_rule_priority string,
    request_creation_time string,
    actions_executed string,
    redirect_url string,
    lambda_error_reason string,
    target_port_list string,
    target_status_code_list string,
    classification string,
    classification_reason string,
    conn_trace_id string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES(
    'serialization.format' = '1',
    'input.regex' = '([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*):([0-9]*) ([^ ]*)[:-]([0-9]*) ([-.0-9]*) ([-.0-9]*) ([-.0-9]*) (|[-0-9]*) (-|[-0-9]*) ([-0-9]*) ([-0-9]*) \"([^ ]*) (.*) (- |[^ ]*)\" \"([^\"]*)\" ([A-Z0-9-_]+) ([A-Za-z0-9.-]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^\"]*)\" ([-.0-9]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^ ]*)\" \"([^\s]+?)\" \"([^\s]+)\" \"([^ ]*)\" \"([^ ]*)\" ?([^ ]*)?( .*)?')
LOCATION 's3://${aws_s3_bucket.alb_access_logs_bucket.bucket}/nginx-alb/AWSLogs/107404535822//elasticloadbalancing/us-east-1/'
EOT
}