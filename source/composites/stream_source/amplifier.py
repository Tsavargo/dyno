from dyno import context


def amplify(input, ctx: context):
    print(f"Input audio: {input}")

    amplified_audio = "[AMPLIFIED] " + input
    print(amplified_audio)
