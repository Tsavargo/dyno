from dyno import context


def handler(input, ctx: context):
    print(f"Input audio: {input}")

    amplified_audio = "[AMPLIFIED] " + input
    ctx.register("amplified_audio", amplified_audio)
    print(amplified_audio)
