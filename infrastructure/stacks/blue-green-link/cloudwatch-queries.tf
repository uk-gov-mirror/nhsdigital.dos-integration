// Introduce a short sleep BEFORE creating query definitions to allow
// recently-created log groups (from other modules in the same apply)
// to propagate. Note: This does NOT guarantee post-create consistency
// of the query definitions themselves, but can reduce immediate read
// failures when the provider plans many resources concurrently.
resource "time_sleep" "wait_for_propagation" {
  create_duration = "45s"
}

resource "aws_cloudwatch_query_definition" "search_for_errors" {
  depends_on = [time_sleep.wait_for_propagation]
  name = "${var.project_id}/${var.blue_green_environment}/search-for-errors"

  log_group_names = [
    "/aws/lambda/${var.change_event_dlq_handler_lambda}",
    "/aws/lambda/${var.dos_db_update_dlq_handler_lambda}",
    "/aws/lambda/${var.event_replay_lambda}",
    "/aws/lambda/${var.ingest_change_event_lambda}",
    "/aws/lambda/${var.send_email_lambda}",
    "/aws/lambda/${var.service_matcher_lambda}",
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp, correlation_id, ods_code, function_name, message
| filter level == 'ERROR'
| sort @timestamp
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_by_correlation_id" {
  depends_on = [aws_cloudwatch_query_definition.search_for_errors]
  name = "${var.project_id}/${var.blue_green_environment}/search-by-correlation-id"

  log_group_names = [
    "/aws/lambda/${var.change_event_dlq_handler_lambda}",
    "/aws/lambda/${var.dos_db_update_dlq_handler_lambda}",
    "/aws/lambda/${var.event_replay_lambda}",
    "/aws/lambda/${var.ingest_change_event_lambda}",
    "/aws/lambda/${var.send_email_lambda}",
    "/aws/lambda/${var.service_matcher_lambda}",
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp, message
| filter correlation_id == 'REPLACE'
| sort @timestamp
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_by_correlation_id_expanded" {
  depends_on = [aws_cloudwatch_query_definition.search_by_correlation_id]
  name = "${var.project_id}/${var.blue_green_environment}/search-by-correlation-id-expanded"

  log_group_names = [
    "/aws/lambda/${var.change_event_dlq_handler_lambda}",
    "/aws/lambda/${var.dos_db_update_dlq_handler_lambda}",
    "/aws/lambda/${var.event_replay_lambda}",
    "/aws/lambda/${var.ingest_change_event_lambda}",
    "/aws/lambda/${var.send_email_lambda}",
    "/aws/lambda/${var.service_matcher_lambda}",
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp,correlation_id,ods_code,level,message_received,function_name, message
| filter correlation_id == 'REPLACE'
| sort @timestamp
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_by_odscode" {
  depends_on = [aws_cloudwatch_query_definition.search_by_correlation_id_expanded]
  name = "${var.project_id}/${var.blue_green_environment}/search-by-odscode"

  log_group_names = [
    "/aws/lambda/${var.change_event_dlq_handler_lambda}",
    "/aws/lambda/${var.dos_db_update_dlq_handler_lambda}",
    "/aws/lambda/${var.event_replay_lambda}",
    "/aws/lambda/${var.ingest_change_event_lambda}",
    "/aws/lambda/${var.send_email_lambda}",
    "/aws/lambda/${var.service_matcher_lambda}",
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp, message
| filter ods_code == 'REPLACE'
| sort @timestamp
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_by_odscode_expanded" {
  depends_on = [aws_cloudwatch_query_definition.search_by_odscode]
  name = "${var.project_id}/${var.blue_green_environment}/search-by-odscode-expanded"

  log_group_names = [
    "/aws/lambda/${var.change_event_dlq_handler_lambda}",
    "/aws/lambda/${var.dos_db_update_dlq_handler_lambda}",
    "/aws/lambda/${var.event_replay_lambda}",
    "/aws/lambda/${var.ingest_change_event_lambda}",
    "/aws/lambda/${var.send_email_lambda}",
    "/aws/lambda/${var.service_matcher_lambda}",
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp,correlation_id,ods_code,level,message_received,function_name, message
| filter ods_code == 'REPLACE'
| sort @timestamp
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_for_invalid_postcode" {
  depends_on = [aws_cloudwatch_query_definition.search_by_odscode_expanded]
  name = "${var.project_id}/${var.blue_green_environment}/search-for-invalid-postcode"

  log_group_names = [
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp,correlation_id,ods_code,level,message_received,function_name, message
| filter report_key == 'INVALID_POSTCODE'
| sort @timestamp
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_for_invalid_opening_times" {
  depends_on = [aws_cloudwatch_query_definition.search_for_invalid_postcode]
  name = "${var.project_id}/${var.blue_green_environment}/search-for-invalid-opening-times"

  log_group_names = [
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp,correlation_id,ods_code,level,message_received,function_name, message
| filter report_key == 'INVALID_OPEN_TIMES'
| sort @timestamp
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_by_email_correlation_id" {
  depends_on = [aws_cloudwatch_query_definition.search_for_invalid_opening_times]
  name = "${var.project_id}/${var.blue_green_environment}/search-by-email-correlation-id"

  log_group_names = [
    "/aws/lambda/${var.service_sync_lambda}",
    "/aws/lambda/${var.send_email_lambda}"
  ]

  query_string = <<EOF
fields correlation_id
| filter message =="Email Correlation Id"
| filter email_correlation_id == "ADD_EMAIL_CORRELATION_ID"
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_by_update_request_success" {
  depends_on = [aws_cloudwatch_query_definition.search_by_email_correlation_id]
  name = "${var.project_id}/${var.blue_green_environment}/update-request-success"

  log_group_names = [
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp, correlation_id
| filter ServiceUpdateSuccess == 1
| sort @timestamp desc
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_by_update_request_failed" {
  depends_on = [aws_cloudwatch_query_definition.search_by_update_request_success]
  name = "${var.project_id}/${var.blue_green_environment}/update-request-failed"

  log_group_names = [
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp, correlation_id, report_key
| filter report_key == DOS_DB_UPDATE_DLQ_HANDLER_RECEIVED_EVENT
| sort @timestamp desc
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_by_dos_data_item_updates" {
  depends_on = [aws_cloudwatch_query_definition.search_by_update_request_failed]
  name = "${var.project_id}/${var.blue_green_environment}/dos-data-item-updates"

  log_group_names = [
    "/aws/lambda/${var.service_sync_lambda}"
  ]

  query_string = <<EOF
fields @timestamp, correlation_id
| filter DoSUpdate == 1
| filter environment == '${var.blue_green_environment}'
| filter field == 'REPLACE'
| sort @timestamp desc
EOF

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_query_definition" "search_for_report_warnings" {
  depends_on = [aws_cloudwatch_query_definition.search_by_dos_data_item_updates]
  name = "${var.project_id}/${var.blue_green_environment}/search-for-report-warnings"

  log_group_names = [
    "/aws/lambda/${var.change_event_dlq_handler_lambda}",
    "/aws/lambda/${var.dos_db_update_dlq_handler_lambda}",
    "/aws/lambda/${var.event_replay_lambda}",
    "/aws/lambda/${var.ingest_change_event_lambda}",
    "/aws/lambda/${var.send_email_lambda}",
    "/aws/lambda/${var.service_matcher_lambda}",
    "/aws/lambda/${var.service_sync_lambda}",
    "/aws/lambda/${var.quality_checker_lambda}"
  ]

  query_string = <<EOF
fields @timestamp, correlation_id, message
| filter level == 'WARNING'
| sort @timestamp desc
EOF

  lifecycle {
    create_before_destroy = false
  }
}


resource "aws_cloudwatch_query_definition" "search_for_quality_checker_logs_with_odscode" {
  depends_on = [aws_cloudwatch_query_definition.search_for_report_warnings]
  name = "${var.project_id}/${var.blue_green_environment}/search-for-quality-checker-logs-with-odscode"

  log_group_names = [
    "/aws/lambda/${var.quality_checker_lambda}"
  ]

  query_string = <<EOF
fields @timestamp, level, message
| filter odscode = 'TO_ADD'
| sort @timestamp asc
EOF

  lifecycle {
    create_before_destroy = false
  }
}
