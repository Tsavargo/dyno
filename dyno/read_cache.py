import os
import pickle
from typing import Any, List, Tuple

import boto3


def read_cache(s3_key: str) -> Tuple[str, List[Any]]:
    bucket_name = os.environ.get("BUCKET_NAME")
    if not bucket_name:
        raise ValueError("The BUCKET_NAME environment variable is not set!")

    s3_client = boto3.client("s3")
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=s3_key)
        data = pickle.load(response["Body"])
        return data

    except Exception as exception:
        print(f"Error reading cache (Key: {s3_key}): {exception}")
        raise
