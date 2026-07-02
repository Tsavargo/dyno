from dyno import context


def handler(input: str, ctx: context):
    print(f"Original audio: {input}")

    processed_audio = "[PROCESSED]" + input
    ctx.register("amplify", processed_audio)
