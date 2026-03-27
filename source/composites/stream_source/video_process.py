from dyno import context


def process(input: str, ctx: context):
    print(f"Original video: {input}")

    processed_video = "[PROCESSED] " + input
    ctx.register("resolution_video_chanel", processed_video)

    metadata = "[METADATA] " + input
    ctx.register("analysis", metadata)
