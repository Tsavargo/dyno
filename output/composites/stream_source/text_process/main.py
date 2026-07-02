from dyno import context


def handler(input: str, ctx: context):
    print(f"Original subtitle: {input}")

    processed_subtitle = "[PROCESSED] " + input
    ctx.register("prcoessed_subtitle", processed_subtitle)
    print(processed_subtitle)
