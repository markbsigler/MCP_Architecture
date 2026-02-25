# Contributing to MCP Architecture Documentation

Thank you for your interest in improving the MCP Architecture documentation. This guide will help you contribute effectively.

## Table of Contents

- [Getting Started](#getting-started)
- [Documentation Structure](#documentation-structure)
- [Adding New Sections](#adding-new-sections)
- [Markdown Standards](#markdown-standards)
- [Build Process](#build-process)
- [Pull Request Process](#pull-request-process)

## Getting Started

### Prerequisites

- Git
- Python 3.11+ (for TOC generation)
- Make (for build automation)
- A markdown editor with linting support (recommended)

### Clone and Setup

```bash
git clone <repository-url>
cd MCP_Architecture
make help  # View available build targets
```

## Documentation Structure

The documentation follows a structured organization:

```text
MCP_Architecture/
├── docs/                           # Documentation root
│   ├── 00-title-page.md           # Overall title page
│   ├── IEEE-29148/                # IEEE 29148:2018 Requirements Specification
│   │   ├── README.md
│   │   ├── SRS.md                 # Software Requirements Specification
│   │   └── methodology/
│   │       └── 02b-requirements-engineering.md  # EARS requirements approach
│   └── IEEE-42010/                # IEEE 42010:2022 Architecture Description
│       ├── README.md
│       ├── AD.md                  # Architecture Description
│       ├── ref/                   # Reference materials
│       │   ├── 00-table-of-contents.md    # Auto-generated TOC
│       │   ├── 00-terminology-guide.md    # Standard terminology
│       │   ├── 98-index-by-topic.md       # Topical index
│       │   └── 99-quick-reference.md      # Quick reference guide
│       └── views/                 # Architecture views (27 implementation guides)
│           ├── 01-architecture-overview.md
│           ├── 01b-architecture-decisions.md
│           ├── 02-security-architecture.md
│           ├── 02a-data-privacy-compliance.md
│           ├── 03-tool-implementation.md
│           ├── 03a-prompt-implementation.md
│           ├── 03b-resource-implementation.md
│           ├── 03c-sampling-patterns.md
│           ├── 03d-decision-trees.md
│           ├── 03e-integration-patterns.md
│           ├── 03f-elicitation-patterns.md
│           ├── 03g-task-patterns.md
│           ├── 03h-multi-server-orchestration.md
│           ├── 03i-ai-service-provider-gateway.md
│           ├── 04-testing-strategy.md
│           ├── 05-observability.md
│           ├── 06-development-lifecycle.md
│           ├── 06a-performance-scalability.md
│           ├── 07-deployment-patterns.md
│           ├── 08-operational-runbooks.md
│           ├── 09-agentic-best-practices.md
│           ├── 10-migration-guides.md
│           ├── 11-troubleshooting.md
│           ├── 12-cost-optimization.md
│           ├── 13-metrics-kpis.md
│           ├── 14-performance-benchmarks.md
│           └── 15-mcp-protocol-compatibility.md
├── dashboards/                     # Grafana dashboard definitions
├── scripts/                        # Build scripts
│   ├── gen_toc.py                 # TOC generator
│   ├── check_links.py             # Link validator
│   └── rewrite_links.py           # Link rewriter
├── Makefile                        # Build automation
├── README.md                       # Project overview
├── CONTRIBUTING.md                 # This file
├── CHANGELOG.md                    # Version history
└── MCP-IEEE-42010-AD.md            # Generated consolidated doc (gitignored)
```

### Section Naming Convention

Files are prefixed with numbers to control their order in the consolidated document:

- `00-*`: Meta sections (title, TOC)
- `01-*`: Architecture foundations
- `02-*`: Security and compliance
- `03-*`: Implementation standards
- `04-08`: Quality, operations, deployment
- `09-10`: Integration and best practices

Subsections use letter suffixes (e.g., `03a`, `03b`) to insert related content without renumbering.

## Adding New Sections

### 1. Create the Markdown File

```bash
# Create a new section file
touch docs/XX-new-section-name.md
```

### 2. Add Version Header

All documentation sections should start with:

```markdown
# Section Title

**Version:** 1.0.0  
**Last Updated:** YYYY-MM-DD  
**Status:** Draft | Active | Deprecated

## Overview

[Content begins here]
```

### 3. Update the Makefile

Add your new section to the `CONTENT_SECTIONS` variable in the Makefile:

```makefile
CONTENT_SECTIONS = \
    docs/01-architecture-overview.md \
    docs/XX-new-section-name.md \    # Add here in order
    docs/02-security-architecture.md \
    # ... rest of sections
```

### 4. Update README.md

Add an entry in the appropriate section of `README.md`:

```markdown
**[New Section Name](docs/XX-new-section-name.md)**

- Key topic 1
- Key topic 2
- Key topic 3
```

### 5. Rebuild Documentation

```bash
make clean  # Remove old build
make md     # Generate new consolidated doc
```

## Markdown Standards

We follow strict markdown linting to ensure consistency and readability.

### Required Rules

#### MD040: Fenced Code Language

**Always specify the language for code blocks:**

```markdown
# ❌ Bad
\`\`\`
def example():
    pass
\`\`\`

# ✅ Good
\`\`\`python
def example():
    pass
\`\`\`
```

Supported languages: `python`, `bash`, `yaml`, `json`, `text`, `mermaid`, `sql`, etc.

#### MD031/MD032: Blank Lines Around Lists and Code

**Surround lists and code blocks with blank lines:**

```markdown
# ❌ Bad
Some text here
- List item 1
- List item 2
More text

# ✅ Good
Some text here

- List item 1
- List item 2

More text
```

#### MD007: List Indentation

**Use consistent indentation (2 spaces for nested lists):**

```markdown
# ✅ Good
- Parent item
  - Child item
  - Another child
    - Grandchild
```

### Heading Standards

- Use Title Case for H1 and H2 headings
- Use sentence case for H3 and below
- Keep headings concise and descriptive
- Avoid special characters in headings (for anchor generation)

### Code Examples

- Use realistic, production-quality examples
- Include comments explaining non-obvious code
- Show both correct (✅) and incorrect (❌) patterns when helpful
- Keep examples focused and concise

### Internal Links

Link to other documentation sections using relative paths:

```markdown
See [Tool Implementation Standards](docs/IEEE-42010/views/03-tool-implementation.md) for details.
```

## Build Process

### Available Make Targets

```bash
make help   # Show all available targets
make toc    # Generate table of contents only
make md     # Build consolidated markdown (default)
make clean  # Remove generated files
```

### How the Build Works

1. **TOC Generation**: `scripts/gen_toc.py` scans all content sections for headings and generates `docs/00-table-of-contents.md`

2. **Concatenation**: The Makefile combines all sections in order:
   - Title page
   - Table of contents
   - Content sections (in CONTENT_SECTIONS order)

3. **Section Breaks**: A `<section class="section-break"></section>` marker is inserted between sections

4. **Output**: The consolidated document is written to `MCP-IEEE-42010-AD.md` (gitignored)

### TOC Generation Details

The `gen_toc.py` script:

- Scans markdown files for `#` and `##` headings
- Generates GitHub-style anchor links
- Creates a nested list structure
- Writes output to `docs/00-table-of-contents.md`

## Pull Request Process

### Before Submitting

1. **Verify your changes build successfully:**

   ```bash
   make clean
   make md
   ```

2. **Check for markdown lint errors:**

   ```bash
   # If you have markdownlint installed
   markdownlint docs/XX-your-new-file.md
   ```

3. **Review the generated consolidated document:**

   ```bash
   less MCP-IEEE-42010-AD.md  # Verify your section appears correctly
   ```

4. **Update version metadata:**
   - Increment version number if making significant changes
   - Update "Last Updated" date
   - Add entry to CHANGELOG.md

### PR Guidelines

1. **Create a descriptive PR title:**
   - `docs: Add section on X`
   - `fix: Correct code example in Y`
   - `refactor: Reorganize Z section`

2. **Write a clear description:**
   - What changed and why
   - Link to related issues
   - Note any breaking changes

3. **Keep PRs focused:**
   - One logical change per PR
   - Avoid mixing content changes with formatting fixes

4. **Get reviews:**
   - Request review from relevant domain experts
   - Address all comments before merging

### Review Criteria

Reviewers will check:

- ✅ Markdown linting passes
- ✅ Build completes successfully
- ✅ Content is technically accurate
- ✅ Examples are realistic and tested
- ✅ Writing is clear and concise
- ✅ Links work correctly
- ✅ Version metadata is updated

## Style Guide

### Voice and Tone

- Use active voice
- Be direct and concise
- Avoid jargon where possible
- Define terms when first introduced

### Code Style

- Follow Python PEP 8 for Python examples
- Use 4 spaces for Python indentation
- Include type hints in Python code
- Add docstrings to functions in examples

### Example Pattern

When showing examples, use this pattern:

```markdown
### Feature Name

Description of what this demonstrates.

**Example:**

\`\`\`python
# Clear comment explaining the example
@mcp.tool()
async def example_tool(param: str) -> dict:
    """Clear docstring."""
    return {"result": param}
\`\`\`

**Key Points:**

- Point 1 explaining important aspect
- Point 2 highlighting best practice
```

## Getting Help

- **Questions**: Open a GitHub issue with the `question` label
- **Bugs**: Open an issue with the `bug` label
- **Feature Requests**: Open an issue with the `enhancement` label
- **Discussions**: Use GitHub Discussions for broader topics

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project (see LICENSE).

---

**Thank you for contributing to the MCP Architecture documentation!**
