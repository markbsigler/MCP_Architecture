#!/usr/bin/env python3
"""Convert Mermaid diagrams in markdown to PNG images for PDF generation.

Usage:
    python3 scripts/convert_mermaid_for_pdf.py <input.md> <output.md> \\
        <output_dir> <prefix>

The script:
1. Extracts Mermaid diagrams from markdown code blocks
2. Saves each diagram to a .mmd file
3. Converts .mmd to .png using mermaid-cli (mmdc)
4. Replaces mermaid code blocks with image references
5. Writes modified markdown to output file
"""

import re
import sys
import os
import subprocess
from pathlib import Path


def convert_mermaid_diagrams(input_file, output_file, output_dir, prefix):
    """Convert Mermaid diagrams to PNG images and update markdown."""

    # Read input markdown
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Create output directory if it doesn't exist
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Counter for diagram numbering
    diagram_count = 0

    def replace_mermaid(match):
        """Replace mermaid code block with PNG image reference."""
        nonlocal diagram_count
        diagram_count += 1

        # Extract diagram content
        diagram_content = match.group(1)

        # Generate file names
        diagram_file = os.path.join(
            output_dir, f'{prefix}_diagram_{diagram_count}.mmd'
        )
        png_file = os.path.join(
            output_dir, f'{prefix}_diagram_{diagram_count}.png'
        )

        # Write diagram to .mmd file
        with open(diagram_file, 'w', encoding='utf-8') as f:
            f.write(diagram_content)

        # Convert to PNG using mermaid-cli
        try:
            subprocess.run(
                [
                    'mmdc', '-i', diagram_file, '-o', png_file,
                    '-b', 'transparent', '-w', '1200'
                ],
                check=True,
                capture_output=True
            )
            print(f'Converted diagram {diagram_count}: {png_file}')
        except subprocess.CalledProcessError as e:
            print(
                f'Warning: Failed to convert diagram {diagram_count}: {e}',
                file=sys.stderr
            )
            # Return original mermaid block if conversion fails
            return match.group(0)

        # Return markdown image reference
        return f'![Diagram {diagram_count}]({png_file})'

    # Replace all mermaid code blocks
    content = re.sub(
        r'```mermaid\n(.*?)\n```',
        replace_mermaid,
        content,
        flags=re.DOTALL
    )

    # Write output markdown
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f'Converted {diagram_count} Mermaid diagrams')
    return diagram_count


def main():
    """Main entry point."""
    if len(sys.argv) != 5:
        print(
            f'Usage: {sys.argv[0]} <input.md> <output.md> '
            f'<output_dir> <prefix>'
        )
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    output_dir = sys.argv[3]
    prefix = sys.argv[4]

    if not os.path.exists(input_file):
        print(
            f'Error: Input file not found: {input_file}',
            file=sys.stderr
        )
        sys.exit(1)

    try:
        convert_mermaid_diagrams(input_file, output_file, output_dir, prefix)
    except Exception as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
