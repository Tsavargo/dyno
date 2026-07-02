from dyno import context


def handler(input, ctx: context):
    print(f"Input video: {input}")

    converted_video = "[CONVERTED] " + input
    ctx.register("converted_video", converted_video)
    print(converted_video)
