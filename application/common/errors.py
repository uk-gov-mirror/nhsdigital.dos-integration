class ValidationError(Exception):
    """Exception raised for errors in the input."""


class DynamoDBError(Exception):
    """Exception raised for all DynamoDB errors."""


class SecretsManagerError(Exception):
    """Exception raised for AWS Secrets Manager errors."""
