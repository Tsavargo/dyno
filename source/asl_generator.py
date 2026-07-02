#!/usr/bin/env python3

"""
AWS Step Functions ASL generator for composite Lambda workflows.
Renders a Jinja2 template using a composites JSON definition and AWS
environment parameters to produce a deployable Step Functions ASL file.
This macro-level orchestrator controls the execution flow between the
previously assembled composite Lambda functions.
"""

import argparse
import json
import os
import sys

from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError


def generate_workflow(
    json_path: str,
    template_path: str,
    output_path: str,
    s3_bucket: str,
    region: str,
    account_id: str,
) -> None:
    """
    Parses the composite JSON configuration and injects it into an ASL template.
    This creates the overarching state machine connecting the composite Lambdas,
    passing necessary AWS environment variables (Region, Account ID, S3 Cache) down.
    """
    # Load the architecture schema
    try:
        with open(json_path, "r", encoding="utf-8") as file:
            data = json.load(file)
    except FileNotFoundError:
        print(f"Error: Input JSON file not found: {json_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as exception:
        print(f"Error: Invalid JSON in {json_path}: {exception}", file=sys.stderr)
        sys.exit(1)

    # Configure Jinja2 Environment for the ASL (JSON) template
    template_abs = os.path.abspath(template_path)
    env = Environment(
        loader=FileSystemLoader(os.path.dirname(template_abs)),
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
        variable_start_string="<<",
        variable_end_string=">>",
        block_start_string="<%",
        block_end_string="%>",
        comment_start_string="<%#",
        comment_end_string="%>",
    )

    try:
        template = env.get_template(os.path.basename(template_abs))
    except FileNotFoundError:
        print(f"Error: Template file not found: {template_abs}", file=sys.stderr)
        sys.exit(1)
    except TemplateSyntaxError as exception:
        print(
            f"Error: Syntax error in template {template_abs}: {exception}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Render the ASL Definition
    # Pass the list of composites so the state machine knows exactly which
    # Lambdas to invoke, and supply AWS identifying info to construct proper ARNs
    generated_asl = template.render(
        composites=data.get("composites", []),
        s3_bucket=s3_bucket,
        aws_region=region,
        aws_account=account_id,
    )

    # Write the finalized State Machine definition to disk
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as file:
        file.write(generated_asl)

    print(f"Success: ASL workflow written to {output_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate an AWS Step Functions ASL file from a composites JSON config.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "-j",
        "--json",
        required=True,
        metavar="PATH",
        help="Path to the composites JSON config file",
    )
    parser.add_argument(
        "-t",
        "--template",
        required=True,
        metavar="PATH",
        help="Path to the Jinja2 ASL template file",
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        metavar="PATH",
        help="Output path for the rendered ASL file",
    )
    parser.add_argument(
        "-b",
        "--bucket",
        required=True,
        metavar="BUCKET",
        help="S3 bucket name used as the Step Functions cache",
    )
    parser.add_argument(
        "-r",
        "--region",
        default="us-east-1",
        metavar="REGION",
        help="AWS region for Lambda ARNs",
    )
    parser.add_argument(
        "-a",
        "--account",
        required=True,
        metavar="ACCOUNT_ID",
        help="AWS account ID used in Lambda ARNs",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    generate_workflow(
        json_path=args.json,
        template_path=args.template,
        output_path=args.output,
        s3_bucket=args.bucket,
        region=args.region,
        account_id=args.account,
    )


if __name__ == "__main__":
    main()
