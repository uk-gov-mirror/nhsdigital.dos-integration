# ##############
# # LAMBDAS
# ##############

variable "change_event_dlq_handler_lambda" {
  type        = string
  description = "Name of fifo dlq handler lambda"
}

variable "dos_db_update_dlq_handler_lambda" {
  type        = string
  description = "Name of cr_fifo dlq handler lambda"
}

variable "event_replay_lambda" {
  type        = string
  description = "Name of event replay lambda"
}

variable "ingest_change_event_lambda" {
  type        = string
  description = "Name of ingest change event lambda"
}

variable "send_email_lambda" {
  type        = string
  description = "Name of send email lambda"
}

variable "service_matcher_lambda" {
  type        = string
  description = "Name of event processor lambda"
}

variable "service_sync_lambda" {
  type        = string
  description = "Name of event sender lambda"
}

variable "quality_checker_lambda" {
  type        = string
  description = "Name of quality checker lambda"
}
