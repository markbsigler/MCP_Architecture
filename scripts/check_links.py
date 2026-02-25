import os
import re
import sys

def check_links(start_path):
    link_pattern = re.compile(r'\[.*?\]\((.*?)\)')
    broken_links = []
    
    # Files to ignore
    ignored_files = {
        'MCP-IEEE-42010-AD.md',
        'CHANGELOG.md',
        'CONTRIBUTING.md' # Has some example links that might be fake, but we fixed the one.
    }
    
    # Directories to ignore
    ignored_dirs = {'.git', '.github', 'node_modules', 'scripts', 'build', 'dist'}

    for dirpath, dirnames, filenames in os.walk(start_path):
        # Filter directories
        dirnames[:] = [d for d in dirnames if d not in ignored_dirs]
        
        for filename in filenames:
            if not filename.endswith('.md'):
                continue
            
            if filename in ignored_files:
                continue
            
            filepath = os.path.join(dirpath, filename)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
            except UnicodeDecodeError:
                print(f"Warning: Could not read {filepath} as UTF-8. Skipping.")
                continue
            
            links = link_pattern.findall(content)
            for link in links:
                # Ignore external links and anchors
                if link.startswith('http') or link.startswith('https') or link.startswith('#') or link.startswith('mailto:'):
                    continue
                
                # Handle relative links
                # Remove anchor from link if present
                link_path = link.split('#')[0]
                
                # If link is just an anchor (e.g. #section), link_path is empty
                if not link_path:
                    continue

                # Resolve absolute path
                if link_path.startswith('/'):
                    # Absolute path relative to project root
                    # We assume start_path is project root for this logic
                    target_path = os.path.join(start_path, link_path.lstrip('/'))
                else:
                    target_path = os.path.join(dirpath, link_path)
                
                # Normalize path
                target_path = os.path.normpath(target_path)
                
                if not os.path.exists(target_path):
                    broken_links.append((filepath, link))

    return broken_links

if __name__ == "__main__":
    root_dir = os.getcwd()
    if len(sys.argv) > 1:
        root_dir = sys.argv[1]
        
    broken = check_links(root_dir)
    if broken:
        print("Found broken links:")
        for source, link in broken:
            print(f"{source} -> {link}")
        sys.exit(1)
    else:
        print("No broken links found.")
