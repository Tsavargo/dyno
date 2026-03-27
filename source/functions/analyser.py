from dyno import context


def analyse(input, ctx: context):
    print(f"Input metadata: {input}")

    analysed_metadata = "[ANALYSED] " + input
    print(analysed_metadata)
