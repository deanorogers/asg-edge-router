resource "aws_s3_bucket" "alb_access_logs_athena_results" {
  bucket = "alb-access-athena-nginx"
  acl    = "private"
}

resource "aws_athena_workgroup" "alb_logs_workgroup" {
  name = "alb_logs_workgroup"

  force_destroy = true

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.alb_access_logs_athena_results.bucket}/athena-results/"
    }
  }

  depends_on = [aws_s3_bucket.alb_access_logs_athena_results]
}

resource "aws_athena_database" "alb_access_logs" {
  name   = "athena_alb_access_logs"
  bucket = aws_s3_bucket.alb_access_logs_athena_results.id
}

resource "aws_athena_named_query" "alb_access_logs" {
  name     = "alb_access_logs"
  database = aws_athena_database.alb_access_logs.name
  #  bucket = aws_s3_bucket.alb_access_logs_bucket.bucket
  workgroup = aws_athena_workgroup.alb_logs_workgroup.name
  query     = <<EOT
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

############################################################################
# Athena optimised
# Crawler defines partitions in metastore
############################################################################

# Classifier Grok-pattern based
resource "aws_glue_classifier" "athena_alb_partitioned_classifier" {
  name   = "athena_alb_partitioned_classifier"

  grok_classifier {
    classification = "alb-logs"
    #    grok_pattern   = <<PATTERN
    #%%{WORD:type} %%{TIMESTAMP_ISO8601:timestamp} %%{DATA:alb_name}
    #PATTERN
    # Grok pattern having removed double-quotes and escaped %
    grok_pattern = "(?:%%{WORD:type}|-) (?:%%{TIMESTAMP_ISO8601:timestamp}|-) (?:%%{DATA:alb_name}|-) (?<client_addr>(?:%%{IP}:%%{NUMBER}|-)) (?<target_addr>(?:%%{IP}:%%{NUMBER}|-)) (?:-?%%{NUMBER:request_processing_time:float}|-) (?:-?%%{NUMBER:target_processing_time:float}|-) (?:-?%%{NUMBER:response_processing_time:float}|-) (?:%%{NUMBER:elb_status_code:int}|-) (?<target_status_code>(?:%%{NUMBER:target_status_code:int}|-)) (?:%%{NUMBER:received_bytes:int}|-) (?:%%{NUMBER:sent_bytes:int}|-) \\\"(?:%%{WORD:http_method}|-) (?:%%{URI:request_url}|-) HTTP/(?:%%{NUMBER:http_version}|-)\\\" \\\"(?:%%{DATA:user_agent}|-)\\\" (?:%%{DATA:ssl_cipher}|-) (?:%%{DATA:ssl_protocol}|-) (?:%%{DATA:target_group_arn}|-) \\\"(?:%%{DATA:trace_id}|-)\\\" (?:%%{DATA:domain_name}|-) (?:%%{DATA:chosen_cert_arn}|-) (?:%%{NUMBER:matched_rule_priority:int}|-) (?:%%{TIMESTAMP_ISO8601:request_creation_time}|-) \\\"(?:%%{WORD:actions_executed}|(?<actions_executed>[A-Za-z]+(?:-[A-Za-z]+)*)|-)\\\" \\\"(?:%%{DATA:redirect_url}|-)\\\" \\\"(?:%%{DATA:error_reason}|-)\\\" \\\"(?<target_addr_2>(?:%%{IP}:%%{NUMBER}|-))\\\" \\\"(?<target_status_code_2>(?:%%{NUMBER}|-))\\\" \\\"(?:%%{DATA:classification}|-)\\\" \\\"(?:%%{DATA:classification_reason}|-)\\\" (?:%%{GREEDYDATA:conn_trace_id}|-)"
  }
}

resource "aws_glue_catalog_database" "athena_alb_partitioned_database" {
  name   = "athena_alb_partitioned_database"
}

resource "aws_glue_crawler" "athena_alb_partitioned_crawler" {
  database_name = aws_glue_catalog_database.athena_alb_partitioned_database.name
  name          = "athena_alb_partitioned_crawler"
  role          = "arn:aws:iam::107404535822:role/service-role/AWSGlueServiceRole-alb-logs-crawler"
  table_prefix  = "athena_alb_partitioned_"

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING" # Options: CRAWL_EVERYTHING | CRAWL_NEW_FOLDERS_ONLY | CRAWL_EVENT_MODE
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }

  classifiers = [aws_glue_classifier.athena_alb_partitioned_classifier.name]

  s3_target {
    path = "s3://${aws_s3_bucket.alb_access_logs_bucket.bucket}/nginx-alb/AWSLogs/107404535822/elasticloadbalancing/us-east-1/"
  }
}