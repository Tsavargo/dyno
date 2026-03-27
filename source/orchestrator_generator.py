import json
import os
import shutil
from typing import Any, Dict, List, Set

# TODO: a kulcsokat ellenőrző logikát ki kell emelni egy újrafelhasználható
# kódrészletbe, ami egy listát kap az ellenőrizendő kulcsokkal

# TODO: a kompozit függvény hívási fájának a levelein kiírni az outputokat
# a felhőben lévő data store-ba, külön függvény implementálása

# TODO: monitoring szinkronizációs ponton

# TODO: dinamikus csomagolás Terraformmal


def get_all_imports(node: Dict[str, Any], imports_set: Set[str]) -> None:
    file_name = node.get("file")
    function_name = node.get("function")

    # Raise an exception if essential keys are missing
    if not file_name or not function_name:
        raise ValueError(
            "Invalid node configuration: Missing 'file' or 'function' key for imports."
        )

    # Safely remove the '.py' extension from the end of the file name
    module_name = file_name.removesuffix(".py")

    # Create unique alias name
    alias_name = f"{module_name}_{function_name}"

    # Add the formatted import string to the set using the alias
    imports_set.add(f"from {module_name} import {function_name} as {alias_name}")

    # Recursively process child branches
    for branch in node.get("branches", []):
        get_all_imports(branch, imports_set)


def generate_node_logic(
    node: Dict[str, Any], input_ctx_name: str, lines: List[str]
) -> None:
    branches = node.get("branches", [])
    if not branches:
        return

    # Raise an exception if essential keys are missing
    func_name = node.get("function")
    if not func_name:
        raise ValueError("Invalid node configuration: Missing 'function' key.")

    lines.append(f"\n\t# --- {func_name} outputs ---")

    # Generate context initializations
    for branch in branches:
        branch_file = branch.get("file")
        branch_function = branch.get("function")
        if not branch_function or not branch_file:
            raise ValueError(
                "Invalid branch configuration: Missing 'function' or 'file' key."
            )
        module_name = branch_file.removesuffix(".py")
        branch_function_alias = f"{module_name}_{branch_function}"
        lines.append(f"\tctx_in_{branch_function_alias} = context()")

    # Generate pattern matching loop
    lines.append(f"\tfor key, value in {input_ctx_name}.items():")

    for iter, branch in enumerate(branches):
        pattern = branch.get("pattern")
        branch_file = branch.get("file")
        branch_function = branch.get("function")
        if not branch_function or not branch_file or not pattern:
            raise ValueError(
                "Invalid branch configuration: Missing 'function' or 'file' or 'pattern' key."
            )
        module_name = branch_file.removesuffix(".py")
        branch_function_alias = f"{module_name}_{branch_function}"

        keyword = "if" if iter == 0 else "elif"
        lines.append(f"\t\t{keyword} re.match(r'{pattern}', str(key)):")
        lines.append(f"\t\t\tctx_in_{branch_function_alias}.register(key, value)")

    # Generate child function calls
    lines.append(f"\n\t# --- {func_name} children ---")
    for branch in branches:
        file_name = branch.get("file")
        module_name = file_name.removesuffix(".py")
        function_name = branch.get("function")
        child_function = f"{module_name}_{function_name}"
        lines.append(f"\tctx_out_{child_function} = context()")
        lines.append(f"\tif len(ctx_in_{child_function}) > 0:")
        lines.append(
            f"\t\tctx_out_{child_function} = parallel(ctx_in_{child_function}, {child_function})"
        )

    # Recursively generate logic for children
    for branch in branches:
        child_function = branch.get("function")
        child_file = branch.get("file")
        child_module = child_file.removesuffix(".py")
        child_alias = f"{child_module}_{child_function}"
        generate_node_logic(branch, f"ctx_out_{child_alias}", lines)


def generate_composite_file(composite_data: Dict[str, Any], output_dir: str) -> None:
    composite_name = composite_data.get("name")
    root = composite_data.get("root")

    # Raise an exception if essential keys are missing
    if not composite_name or not root:
        raise ValueError(
            "Invalid composite configuration: Missing 'name' or 'root' key."
        )

    lines = [
        "import re",
        "from dyno import context",
        "from dyno import parallel",
    ]

    # Collect and append imports
    imports: Set[str] = set()
    get_all_imports(root, imports)
    lines.extend(list(imports))

    # Generate the handler function definition
    lines.append(f"\n\ndef handler_{composite_name}(initial_input):")
    lines.append("\t# --- Run root ---")
    lines.append("\troot_ctx = context()")

    root_function = root.get("function")
    root_file = root.get("file")
    if not root_function or not root_file:
        raise ValueError(
            "Invalid root configuration: Missing 'function' or 'file' key."
        )

    root_module = root_file.removesuffix(".py")

    lines.append(f"\t{root_module}_{root_function}(initial_input, root_ctx)")

    # Call the logic generator
    generate_node_logic(root, "root_ctx", lines)

    lines.append("\n\treturn 'Successful run'")

    # Write the generated code to a file safely
    file_path = os.path.join(output_dir, f"{composite_name}.py")
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"[SUCCESS] Generated file: {file_path}")


def collect_files(node: Dict[str, Any], input_dir: str, output_dir: str) -> None:
    file_name = node.get("file")

    if file_name:
        # Safely join paths regardless of OS
        file_path = os.path.join(input_dir, file_name)

        try:
            shutil.copy(file_path, output_dir)
            print(f"[COPIED] file: {file_path} to: {output_dir}")
        except FileNotFoundError:
            print(f"[ERROR] File not found: {file_path}")

    # Recursively process child branches
    for branch in node.get("branches", []):
        collect_files(branch, input_dir, output_dir)


def generate_project(json_file_path: str, input_dir: str, output_dir: str) -> None:
    # Create the output directory safely
    os.makedirs(output_dir, exist_ok=True)

    with open(json_file_path, "r", encoding="utf-8") as file:
        data = json.load(file)

    composites = data.get("composites", [])
    print(f"Project loaded. Found {len(composites)} composite functions.\n")

    # Process each composite function
    for composite_function in composites:
        composite_name = composite_function.get("name")
        composite_root = composite_function.get("root")

        # Raise an exception if essential keys are missing
        if not composite_name or not composite_root:
            raise ValueError(
                f"Invalid project configuration: '{composite_name}' composite function is missing its 'name' or 'root'."
            )

        # Safely join paths regardless of OS
        composite_dir = os.path.join(output_dir, composite_name)

        # Create the specific directory for the composite
        os.makedirs(composite_dir, exist_ok=True)

        # Copy atomic functions to the composite directory
        collect_files(composite_root, input_dir, composite_dir)
        # Generates the orchestrator file
        generate_composite_file(composite_function, composite_dir)

    print("Project generation completed!")


# Run
generate_project("../schema/stream.json", "./functions/", "./composites/")
