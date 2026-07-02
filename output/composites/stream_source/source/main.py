from dyno import context


def handler(input, ctx: context):
    print(f"[{input}] Stream function generates video, audio and subtitle chanels")

    video = "ORIGINAL VIDEO CHANEL"
    ctx.register("video", video)

    english_audio = "ENGLISH AUDIO CHANEL"
    hungarian_audio = "HUNGARIAN AUDIO CHANEL"
    ctx.register("audio", english_audio)
    ctx.register("audio", hungarian_audio)

    english_subtitle = "ENGLISH SUBTITLE CHANEL"
    hungarian_subtitle = "HUNGARIAN SUBTITLE CHANEL"
    german_subtitle = "GERMAN SUBTITLE CHANEL"
    ctx.register("subtitle", english_subtitle)
    ctx.register("subtitle", hungarian_subtitle)
    ctx.register("subtitle", german_subtitle)
