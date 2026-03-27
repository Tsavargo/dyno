from dyno import context


def convert(input, ctx: context):
    print(f"Input video: {input}")

    converted_video = "[CONVERTED] " + input
    print(converted_video)
