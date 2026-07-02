import os
import pickle
import uuid

import boto3

from dyno import context


def write_cache(ctx: context) -> None:
    bucket_name = os.environ.get("BUCKET_NAME")
    if not bucket_name:
        raise ValueError("The BUCKET_NAME environment variable is not set!")
    s3_client = boto3.client("s3")

    current_key = "none"
    try:
        for key, objects in ctx.items():
            current_key = key

            # serialize each object and upload it to a specific subdirectory
            for object in objects:
                file_id = str(uuid.uuid4())
                runtime_id = ctx.runtime_id
                s3_key = f"stepfunctions-cache/{runtime_id}/{key}/{file_id}.pkl"
                serialized_data = pickle.dumps(object)
                s3_client.put_object(
                    Bucket=bucket_name, Key=s3_key, Body=serialized_data
                )

    except Exception as exception:
        print(f"Error writing cache for key {current_key}: {exception}")
        raise
