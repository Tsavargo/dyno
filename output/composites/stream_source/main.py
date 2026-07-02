import uuid
from dyno import context, parallel, write_cache
from source.main import handler as source_trigger
from audio_process.main import handler as audio_process_audio
from amplifier.main import handler as amplifier_amplify
from text_process.main import handler as text_process_subtitle


def lambda_handler(event, aws_context):
    runtime_id = str(uuid.uuid4())
    ctx = context(runtime_id)
    source_trigger("trigger", ctx)
    parallel(ctx, "audio", audio_process_audio)
    parallel(ctx, "amplify", amplifier_amplify)
    parallel(ctx, "subtitle", text_process_subtitle)
    write_cache(ctx)
    return {
        "statusCode": 200,
        "body": "Successful run",
        "runtimeID": runtime_id,
    }
