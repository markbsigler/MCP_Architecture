import re
import sys
import os

def rewrite_links(content, filename):
    """
    Rewrite relative file links to anchor links.
    e.g. [Link](02-security.md) -> [Link](#security-architecture)
    """
    
    # Regex to find markdown links: [text](url)
    link_pattern = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')
    
    def replace_link(match):
        text = match.group(1)
        url = match.group(2)
        
        # Ignore external links, anchors, and mailto
        if url.startswith('http') or url.startswith('#') or url.startswith('mailto:'):
            return match.group(0)
        
        # Handle relative file links
        if url.endswith('.md'):
            # Extract filename without extension
            basename = os.path.basename(url)
            # Remove extension
            basename_no_ext = os.path.splitext(basename)[0]
            
            # Convert to anchor format (kebab-case, lowercase)
            # This is a heuristic; it assumes the target file has a top-level heading 
            # that matches the filename or is predictable.
            # A better approach would be to scan the target file for the first H1.
            
            # For now, let's try to map known files to their likely H1 anchors
            # or just use the filename as a best guess if we can't read the file here.
            # Since we are piping content, we might not have easy access to other files 
            # unless we pass the root dir.
            
            # However, the standard GitHub/Markdown anchor generation usually takes the header text.
            # Let's try to read the target file to find the first H1.
            
            # Resolve path relative to the current file being processed
            # The 'filename' arg is the path to the current file
            current_dir = os.path.dirname(filename)
            target_path = os.path.join(current_dir, url)
            
            if os.path.exists(target_path):
                try:
                    with open(target_path, 'r', encoding='utf-8') as f:
                        for line in f:
                            if line.startswith('# '):
                                # Found H1
                                header = line[2:].strip()
                                # Convert to anchor: lowercase, replace spaces with hyphens, remove special chars
                                anchor = header.lower().replace(' ', '-')
                                anchor = re.sub(r'[^\w-]', '', anchor)
                                return f'[{text}](#{anchor})'
                except Exception as e:
                    sys.stderr.write(f"Warning: Could not read {target_path}: {e}\n")
            
            # Fallback: just use the filename without numbers and extension as a guess
            # e.g. 02-security-architecture.md -> security-architecture
            anchor = basename_no_ext
            # Remove leading numbers and dash if present (e.g. 01-overview -> overview)
            anchor = re.sub(r'^\d+[-_]', '', anchor)
            return f'[{text}](#{anchor})'
            
        return match.group(0)

    return link_pattern.sub(replace_link, content)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 rewrite_links.py <filename>")
        sys.exit(1)
        
    filename = sys.argv[1]
    
    try:
        # Read from stdin (content is piped in Makefile)
        # Wait, the Makefile does `cat $$f >> $(COMBINED_MD)`.
        # We need to intercept this.
        # Better: `python3 scripts/rewrite_links.py $$f >> $(COMBINED_MD)`
        
        # So we read the file specified in arg, process it, and print to stdout
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
            
        new_content = rewrite_links(content, filename)
        print(new_content, end='')
        
    except Exception as e:
        sys.stderr.write(f"Error processing {filename}: {e}\n")
        sys.exit(1)
