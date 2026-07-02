from dyno import context, parallel, read_cache, write_cache
from video_process.main import handler as video_process_video
from video_convert.main import handler as video_convert_convert
from analyser.main import handler as analyser_analyse


def lambda_handler(event, aws_context):
    runtime_id = event["runtimeID"]
    item_key = event["item"]
    ctx = context(runtime_id)
    object = read_cache(item_key)
    ctx.register("video", object)
    video_process_video("video", ctx)
    parallel(ctx, "convert", video_convert_convert)
    parallel(ctx, "analyse", analyser_analyse)
    write_cache(ctx)
    return {
        "statusCode": 200,
        "body": "Successful run",
        "runtimeID": runtime_id,
    }
