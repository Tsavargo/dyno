import re

from amplifier import amplify as amplifier_amplify
from analyser import analyse as analyser_analyse
from audio_process import process as audio_process_process
from text_process import process as text_process_process
from video_converter import convert as video_converter_convert
from video_process import process as video_process_process

from dyno import context, parallel
from source import stream as source_stream


def handler_stream_source(initial_input):
    # --- Run root ---
    root_ctx = context()
    source_stream(initial_input, root_ctx)

    # --- stream outputs ---
    ctx_in_video_process_process = context()
    ctx_in_audio_process_process = context()
    ctx_in_text_process_process = context()
    for key, value in root_ctx.items():
        if re.match(r"video", str(key)):
            ctx_in_video_process_process.register(key, value)
        elif re.match(r"audio", str(key)):
            ctx_in_audio_process_process.register(key, value)
        elif re.match(r"subtitle", str(key)):
            ctx_in_text_process_process.register(key, value)

    # --- stream children ---
    ctx_out_video_process_process = context()
    if len(ctx_in_video_process_process) > 0:
        ctx_out_video_process_process = parallel(
            ctx_in_video_process_process, video_process_process
        )
    ctx_out_audio_process_process = context()
    if len(ctx_in_audio_process_process) > 0:
        ctx_out_audio_process_process = parallel(
            ctx_in_audio_process_process, audio_process_process
        )
    ctx_out_text_process_process = context()
    if len(ctx_in_text_process_process) > 0:
        ctx_out_text_process_process = parallel(
            ctx_in_text_process_process, text_process_process
        )

    # --- process outputs ---
    ctx_in_video_converter_convert = context()
    ctx_in_analyser_analyse = context()
    for key, value in ctx_out_video_process_process.items():
        if re.match(r"resolution", str(key)):
            ctx_in_video_converter_convert.register(key, value)
        elif re.match(r"analysis", str(key)):
            ctx_in_analyser_analyse.register(key, value)

    # --- process children ---
    ctx_out_video_converter_convert = context()
    if len(ctx_in_video_converter_convert) > 0:
        ctx_out_video_converter_convert = parallel(
            ctx_in_video_converter_convert, video_converter_convert
        )
    ctx_out_analyser_analyse = context()
    if len(ctx_in_analyser_analyse) > 0:
        ctx_out_analyser_analyse = parallel(ctx_in_analyser_analyse, analyser_analyse)

    # --- process outputs ---
    ctx_in_amplifier_amplify = context()
    for key, value in ctx_out_audio_process_process.items():
        if re.match(r"amplify", str(key)):
            ctx_in_amplifier_amplify.register(key, value)

    # --- process children ---
    ctx_out_amplifier_amplify = context()
    if len(ctx_in_amplifier_amplify) > 0:
        ctx_out_amplifier_amplify = parallel(
            ctx_in_amplifier_amplify, amplifier_amplify
        )

    return "Successful run"


if __name__ == "__main__":
    handler_stream_source("INIT")
