#!/usr/bin/env python3

"""
Lambda Orchestrator Generator

This script parses a configuration JSON to assemble "composite" Lambda functions.
A composite is a unified Lambda package composed of multiple "atomic" functions.
The script handles copying the required atomic modules into a target directory
and generates a 'main.py' orchestrator file using a Jinja2 template. This orchestrator
manages the internal input/output flow between the atomic functions within the same Lambda.
"""

import argparse
import json
import os
import shutil
import sys
from typing import Any, Dict, List


def validate_required_keys(
    node: Dict[str, Any], required_keys: List[str], node_index: int
) -> None:
    """
    Validates that an atomic function configuration node contains all strictly required keys.
    Prevents generating invalid imports or handler mappings later in the process.
    """
    missing = [key for key in required_keys if key not in node]
    if missing:
        raise ValueError(
            f"Invalid configuration at node index {node_index}. "
            f"Missing key(s): {missing}. Node: {node}"
        )


def build_import_alias(node: Dict[str, Any]) -> str:
    """
    Constructs a unique alias for the imported atomic module to prevent namespace collisions.
    Format: {module_name}_{input_parameter_name}
    """
    return f"{node['module']}_{node['input']}"


def copy_component_files(
    functions: List[Dict[str, Any]], source_dir: str, destination_dir: str
) -> None:
    """
    Gathers the source code of the individual atomic functions and copies them
    into the composite Lambda's deployment package directory.
    """
    for function in functions:
        module_name = function.get("module")
        if not module_name:
            raise ValueError(
                f"Function config is missing required 'module' field: {function}"
            )

        src = os.path.join(source_dir, module_name)
        dst = os.path.join(destination_dir, module_name)

        # Fail fast: a missing module directory means the generated orchestrator
        # would fail at Lambda runtime with an ImportError.
        if not os.path.isdir(src):
            raise FileNotFoundError(
                f"Atomic function directory not found: {src}\n"
                f"  Referenced by composite config but the module does not exist.\n"
                f"  Create the directory and add a main.py with a handler function."
            )

        # Copy the atomic module into the composite package structure
        shutil.copytree(src, dst, dirs_exist_ok=True)

        # Ensure the copied directory acts as a valid Python package
        init_path = os.path.join(dst, "__init__.py")
        if not os.path.exists(init_path):
            open(init_path, "a").close()


def generate_orchestration_file(
    composite: Dict[str, Any], output_dir: str, template_file: str, is_root: bool
) -> None:
    """
    Renders the 'main.py' entrypoint for the composite Lambda.
    This orchestrator dictates how data flows between the bundled atomic functions.
    """
    from jinja2 import Environment, FileSystemLoader

    composite_name = composite.get("name")
    nodes = composite.get("functions", [])

    if not composite_name or not nodes:
        raise ValueError(
            "Invalid composite configuration: missing 'name' or 'functions'."
        )

    for index, node in enumerate(nodes):
        validate_required_keys(node, ["module", "input"], index)

    # The first atomic function receives the direct invocation event payload
    first_node = nodes[0]
    first_alias = build_import_alias(first_node)
    first_input_key = first_node["input"]

    # Subsequent atomic functions might be executed in parallel or sequentially
    # based on the template logic. We prep the payload context here.
    parallel_steps = [
        {"alias": build_import_alias(node), "input_key": node["input"]}
        for node in nodes[1:]
    ]

    # Generate distinct import statements for each atomic function, avoiding duplicates
    import_statements = list(
        dict.fromkeys(
            f"from {node['module']}.main import handler as {build_import_alias(node)}"
            for node in nodes
        )
    )

    # Configure the Jinja2 environment with custom delimiters to avoid conflicts
    # with native Python syntax.
    template_path = os.path.abspath(template_file)
    env = Environment(
        loader=FileSystemLoader(os.path.dirname(template_path)),
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
    template = env.get_template(os.path.basename(template_path))

    # Inject the mapping logic into the template
    rendered = template.render(
        is_root=is_root,
        import_statements=import_statements,
        first_alias=first_alias,
        first_input_key=first_input_key,
        parallel_steps=parallel_steps,
    )

    # Persist the orchestrated entrypoint into the target Lambda directory
    output_file = os.path.join(output_dir, "main.py")
    with open(output_file, "w", encoding="utf-8") as file:
        file.write(rendered)

    print(f"[OK] {'root' if is_root else 'map ':4} {composite_name} → {output_file}")


def generate_project(
    config_file: str, source_dir: str, output_dir: str, template_dir: str
) -> None:
    """
    Main controller for the project generation pipeline. It reads the composite definitions,
    creates the output directories, copies dependencies, and triggers the orchestrator generator.
    """
    if not os.path.exists(config_file):
        print(f"[ERROR] Config file not found: {config_file}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    with open(config_file, "r", encoding="utf-8") as file:
        config = json.load(file)

    composites = config.get("composites", [])
    if not composites:
        print("[ERROR] No composites found in config.", file=sys.stderr)
        sys.exit(1)

    print(f"Loaded {len(composites)} composite(s) from {config_file}\n")

    # Process each composite defined in the JSON configuration
    for index, composite in enumerate(composites):
        composite_name = composite.get("name")
        functions = composite.get("functions")

        if not composite_name or not functions:
            raise ValueError(
                f"Composite at index {index} is missing 'name' or 'functions'."
            )

        composite_output_dir = os.path.join(output_dir, composite_name)
        os.makedirs(composite_output_dir, exist_ok=True)

        # Bring in the atomic function source code
        copy_component_files(functions, source_dir, composite_output_dir)

        # Build the glue code that strings them together
        generate_orchestration_file(
            composite,
            composite_output_dir,
            template_dir,
            is_root=(index == 0),
        )

    print("\n[DONE] Project generation completed.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Lambda orchestrator files from a composites JSON config.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "-c",
        "--config",
        required=True,
        metavar="PATH",
        help="Path to the composites JSON config file",
    )
    parser.add_argument(
        "-s",
        "--source",
        required=True,
        metavar="DIR",
        help="Directory containing the atomic components",
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        metavar="DIR",
        help="Output directory for generated composite Lambdas",
    )
    parser.add_argument(
        "-t",
        "--template",
        required=True,
        metavar="FILE",
        help="Path to the Jinja2 Python template",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    generate_project(
        config_file=args.config,
        source_dir=args.source,
        output_dir=args.output,
        template_dir=args.template,
    )


if __name__ == "__main__":
    main()
