from dataclasses import dataclass
from datetime import datetime
from json import JSONDecodeError, loads
from typing import Self
from zoneinfo import ZoneInfo

from aws_lambda_powertools.logging import Logger
from psycopg import Connection
from psycopg.rows import DictRow

from ..service_update_logger import ServiceUpdateLogger
from common.constants import DI_CHANGE_ITEMS, DOS_INTEGRATION_USER_NAME
from common.dos_db_connection import connect_to_db_writer, query_dos_db

logger = Logger(child=True)


@dataclass(repr=True)
class PendingChange:
    """A class representing a pending change from the DoS database with useful information about the change."""

    id: str  # Id of the pending change from the change table
    value: str  # Value of the pending change as a JSON string
    creatorsname: str  # User name of the user who made the change
    email: str  # Email address of the user who made the change
    typeid: str  # Type id of the service
    name: str  # Name of the service
    uid: str  # Uid of the service
    user_id: str  # User id of the user who made the change

    def __init__(self: Self, db_cursor_row: dict) -> None:
        """Sets the attributes of this object to those found in the db row.

        Args:
            db_cursor_row (dict): row from db as key/val pairs.
        """
        for row_key, row_value in db_cursor_row.items():
            setattr(self, row_key, row_value)

    def __repr__(self: Self) -> str:
        """Returns a string representation of this object.

        Returns:
            str: String representation of this object
        """
        try:
            value = loads(self.value)
            value["initiator"]["userid"] = "Hidden in Logs"
            value["approver"] = "Hidden in Logs"
        except JSONDecodeError:
            value = "Unable to show value as unable to decode JSON to remove sensitive user data"

        return (
            f"PendingChange(id={self.id}, value={value}, typeid={self.typeid}, "
            f"name={self.name}, uid={self.uid}, user_id={self.user_id})"
        )

    def is_valid(self: Self) -> bool:
        """Checks if the pending change is valid.

        Returns:
            bool: True if the pending change is valid, False otherwise
        """
        try:
            value_dict = loads(self.value)
            changes = value_dict["new"]
            is_types_valid = [change in DI_CHANGE_ITEMS for change in changes]
            return all(is_types_valid)
        except Exception:
            logger.exception(
                f"Invalid JSON at pending change {self.id}, unable to show as contains sensitive user data",
            )
            return False


def check_and_remove_pending_dos_changes(service_id: str) -> None:
    """Checks for pending changes in DoS and removes them if they exist.

    Args:
        service_id (str): The ID of the service to check
    """
    with connect_to_db_writer() as connection:
        pending_changes = get_pending_changes(connection=connection, service_id=service_id)
        if pending_changes != [] and pending_changes is not None:
            logger.info("Pending Changes to be rejected", pending_changes=pending_changes)
            reject_pending_changes(connection=connection, pending_changes=pending_changes)
            connection.commit()
            log_rejected_changes(pending_changes)
            logger.info("All pending changes rejected")
        else:
            logger.info("No valid pending changes found")


def get_pending_changes(connection: Connection, service_id: str) -> list[PendingChange] | None:
    """Gets pending changes for a service ID.

    Args:
        connection (connection): The connection to the DoS database
        service_id (str): The ID of the service to check

    Returns:
        Optional[List[Dict[str, Any]]]: A list of pending changes or None if there are no pending changes
    """
    sql_query = (
        "SELECT c.id, c.value, c.creatorsname, u.email, s.typeid, s.name, s.uid, u.id AS user_id "
        "FROM changes c INNER JOIN users u ON u.username = c.creatorsname "
        "INNER JOIN services s ON s.id = c.serviceid "
        "WHERE serviceid=%(SERVICE_ID)s AND approvestatus='PENDING'"
    )
    query_vars = {"SERVICE_ID": service_id}
    cursor = query_dos_db(connection=connection, query=sql_query, query_vars=query_vars)
    response_rows: list[DictRow] = cursor.fetchall()
    cursor.close()
    if not response_rows:
        return None
    logger.info(f"Pending changes found for Service ID {service_id}")
    pending_changes: list[PendingChange] = []
    for row in response_rows:
        pending_change = PendingChange(row)
        logger.info(f"Pending change found: {pending_change}", pending_change=pending_change)
        if pending_change.is_valid():
            logger.debug(f"Pending change is valid: {pending_change.id}", pending_change=pending_change)
            pending_changes.append(pending_change)
        else:
            logger.info(f"Pending change {pending_change.id} is invalid", pending_change=pending_change)

    return pending_changes


def reject_pending_changes(connection: Connection, pending_changes: list[PendingChange]) -> None:
    """Rejects pending changes from the database.

    Args:
        connection (connection): The connection to the DoS database
        pending_changes (List[PendingChange]): The pending change to reject
    """
    conditions = (
        f"id='{pending_changes[0].id}'"
        if len(pending_changes) == 1
        else f"""id in ({",".join(f"'{change.id}'" for change in pending_changes)})"""
    )
    # SQL Injection is prevented by the query only using data from DoS DB
    sql_query = (
        "UPDATE changes SET approvestatus='REJECTED', "  # noqa: S608
        "modifiedtimestamp=%(TIMESTAMP)s, modifiersname=%(USER_NAME)s"
        f""" WHERE {conditions}"""
    )
    query_vars = {
        "USER_NAME": DOS_INTEGRATION_USER_NAME,
        "TIMESTAMP": datetime.now(ZoneInfo("Europe/London")),
    }
    cursor = query_dos_db(connection=connection, query=sql_query, query_vars=query_vars)
    cursor.close()
    logger.info("Rejected pending change/s", pending_changes=pending_changes)


def log_rejected_changes(pending_changes: list[PendingChange]) -> None:
    """Logs the rejected changes.

    Args:
        pending_changes (List[PendingChange]): The pending changes to log
    """
    for pending_change in pending_changes:
        ServiceUpdateLogger(
            service_uid=pending_change.uid,
            service_name=pending_change.name,
            type_id=pending_change.typeid,
            odscode="",
        ).log_rejected_change(pending_change.id)
