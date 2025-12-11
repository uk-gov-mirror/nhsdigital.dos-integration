# from email.mime.multipart import MIMEMultipart
# from email.mime.text import MIMEText
# from os import environ
# from smtplib import SMTP, SMTPException

# from aws_lambda_powertools.logging import Logger
# from aws_lambda_powertools.tracing import Tracer
# from aws_lambda_powertools.utilities.typing import LambdaContext

# from common.middlewares import unhandled_exception_logging_hidden_event
# from common.secretsmanager import get_secret
# from common.types import EmailMessage

# tracer = Tracer()
# logger = Logger()


# @tracer.capture_lambda_handler()
# @unhandled_exception_logging_hidden_event
# @logger.inject_lambda_context(clear_state=True, correlation_id_path="correlation_id")
# def lambda_handler(event: EmailMessage, context: LambdaContext) -> None:  # noqa: ARG001
#     """Entrypoint handler for the send_email lambda using NHS mail relay.

#     Args:
#         event (EmailMessage): Lambda function invocation event
#         context (LambdaContext): Lambda function context object
#     """
#     logger.append_keys(user_id=event["user_id"], change_id=event["change_id"], s3_filename=event["s3_filename"])
#     logger.info("Starting send_email lambda (NHS relay)")
#     send_email_via_nhs_relay(
#         email_address=event["recipient_email_address"],
#         html_content=event["email_body"],
#         subject=event["email_subject"],
#         correlation_id=event["correlation_id"],
#     )


# def send_email_via_nhs_relay(email_address: str, html_content: str, subject: str, correlation_id: str) -> None:
#     """Send an email using NHS mail relay (relay.nhs.uk) with anonymous authentication.

#     The NHS mail relay provides:
#     - Anonymous authentication (no credentials needed)
#     - Opportunistic TLS support
#     - 35MB message size limit
#     - Automatic rate limiting

#     Requirements:
#     - Sender must be from a valid NHS domain
#     - Sending IP must have reverse DNS (PTR) record registered with dnsteam@nhs.net
#     - Connection from HSCN network or registered external IP

#     Args:
#         email_address (str): Email address to send the email to
#         html_content (str): HTML content of the email
#         subject (str): Subject of the email
#         correlation_id (str): Correlation ID of the email

#     Raises:
#         SMTPException: If email sending fails
#     """
#     aws_account_name = environ["AWS_ACCOUNT_NAME"]
#     if aws_account_name != "nonprod" or "email" in correlation_id:
#         logger.info("Preparing to send email via NHS mail relay")
#         email_secrets = get_secret(environ["EMAIL_SECRET_NAME"])
#         di_system_email_address = email_secrets["DI_SYSTEM_MAILBOX_ADDRESS"]

#         # Prepare email message with required headers
#         msg = MIMEMultipart("alternative")
#         msg["Subject"] = subject
#         msg["From"] = di_system_email_address
#         msg["To"] = email_address
#         msg.attach(MIMEText(html_content, "html"))
#         logger.info("Email content prepared")

#         smtp = None
#         try:
#             # Connect to NHS mail relay (anonymous auth, no credentials needed)
#             smtp = SMTP(host="relay.nhs.uk", port=587, timeout=15)
#             logger.info("Connected to NHS mail relay")
#             smtp.ehlo()

#             # Use opportunistic TLS if available
#             try:
#                 smtp.starttls()
#                 smtp.ehlo()  # Re-identify after STARTTLS
#                 logger.info("TLS enabled")
#             except Exception as tls_error:
#                 logger.warning(f"TLS not available, continuing with plain text: {tls_error}")

#             # Send email (no authentication required for NHS relay)
#             smtp.sendmail(from_addr=di_system_email_address, to_addrs=[email_address], msg=msg.as_string())
#             logger.warning("Sent email via NHS relay", cloudwatch_metric_filter_matching_attribute="EmailSent")
#         except SMTPException:
#             logger.exception("Email failed via NHS relay", cloudwatch_metric_filter_matching_attribute="EmailFailed")
#             raise
#         except Exception as e:
#             logger.exception("Email failed via NHS relay", cloudwatch_metric_filter_matching_attribute="EmailFailed")
#             raise SMTPException(f"An error occurred while sending the email via NHS relay: {e}") from e
#         finally:
#             if smtp:
#                 try:
#                     smtp.quit()
#                     logger.info("Disconnected from NHS mail relay")
#                 except Exception:
#                     # Ignore errors on cleanup
#                     pass
