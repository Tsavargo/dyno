from dyno import context


def handler(input: str, ctx: context):
    print(f"Original video: {input}")

    processed_video = "[PROCESSED] " + input
    ctx.register("convert", processed_video)

    metadata = "[METADATA] " + input
    ctx.register("analyse", metadata)
