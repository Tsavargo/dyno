import os
import pickle
import uuid
from typing import List

import boto3

from dyno import context


def write_cache(ctx: context) -> List[str]:
    bucket_name = os.environ.get("BUCKET_NAME")
    if not bucket_name:
        raise ValueError("The BUCKET_NAME environment variable is not set!")
    s3_client = boto3.client("s3")

    s3_keys = []

    current_key = "none"
    try:
        for key, obj_list in ctx.items():
            current_key = key
            file_id = str(uuid.uuid4())

            s3_key = f"stepfunctions-cache/{key}_{file_id}.pkl"
            serialized_data = pickle.dumps((key, obj_list))
            s3_client.put_object(Bucket=bucket_name, Key=s3_key, Body=serialized_data)

            s3_keys.append(s3_key)

    except Exception as exception:
        print(f"Error writing cache for key {current_key}: {exception}")
        raise

    return s3_keys
