from dyno import context


def process(input: str, ctx: context):
    print(f"Original audio: {input}")

    processed_audio = "[PROCESSED]" + input
    ctx.register("amplify", processed_audio)
