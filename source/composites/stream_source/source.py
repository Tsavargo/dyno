from dyno import context


def stream(input, ctx: context):
    print(f"[{input}] Stream function generates video, audio and subtitle chanels")

    video = "ORIGINAL VIDEO CHANEL"
    ctx.register("video1", video)

    english_audio = "ENGLISH AUDIO CHANEL"
    hungarian_audio = "HUNGARIAN AUDIO CHANEL"
    ctx.register("audio_eng", english_audio)
    ctx.register("audio_hun", hungarian_audio)

    english_subtitle = "ENGLISH SUBTITLE CHANEL"
    hungarian_subtitle = "HUNGARIAN SUBTITLE CHANEL"
    german_subtitle = "GERMAN SUBTITLE CHANEL"
    ctx.register("subtitle_eng", english_subtitle)
    ctx.register("subtitle_hun", hungarian_subtitle)
    ctx.register("subtitle_ger", german_subtitle)
