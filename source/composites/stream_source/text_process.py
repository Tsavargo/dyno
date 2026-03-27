from dyno import context


def process(input: str, ctx: context):
    print(f"Original subtitle: {input}")

    processed_subtitle = "[PROCESSED] " + input
    print(processed_subtitle)
