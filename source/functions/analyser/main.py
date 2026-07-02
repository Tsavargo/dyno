from dyno import context


def handler(input, ctx: context):
    print(f"Input metadata: {input}")

    analysed_metadata = "[ANALYSED] " + input
    ctx.register("analysed_metadata", analysed_metadata)
    print(analysed_metadata)
