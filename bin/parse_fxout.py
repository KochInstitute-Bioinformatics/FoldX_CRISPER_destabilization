#!/usr/bin/env python3
"""
Simple parser for FoldX output files.
"""
import sys
import os
import re

def parse_fxout_file(fxout_file):
    """Parse a single fxout file and extract ddG values"""
    results = []
    
    try:
        with open(fxout_file, 'r') as f:
            lines = f.readlines()
            
        # Look for the summary table in FoldX output
        in_summary = False
        for line in lines:
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
                
            # Look for the start of results table
            if 'Pdb' in line and 'SD' in line and 'ddG' in line:
                in_summary = True
                continue
                
            if in_summary and line and not line.startswith('#'):
                # Split the line and try to extract ddG
                parts = line.split()
                if len(parts) >= 2:
                    try:
                        # Usually ddG is in the second column
                        ddg = float(parts[1])
                        mutation_info = parts[0] if len(parts) > 0 else "Unknown"
                        results.append((mutation_info, ddg))
                    except (ValueError, IndexError):
                        continue
                        
    except Exception as e:
        print(f"Error parsing {fxout_file}: {e}", file=sys.stderr)
        
    return results

def main():
    if len(sys.argv) < 2:
        print("Usage: parse_fxout.py <fxout_files...>")
        sys.exit(1)
    
    print("File,Gene,Mutation,ddG")
    
    for fxout_file in sys.argv[1:]:
        if not fxout_file.endswith('.fxout'):
            continue
            
        # Extract gene and mutation from filename if possible
        basename = os.path.basename(fxout_file)
        gene = "Unknown"
        mutation = "Unknown"
        
        # Try to parse filename for gene/mutation info
        if '_' in basename:
            parts = basename.replace('.fxout', '').split('_')
            if len(parts) >= 2:
                gene = parts[0]
                mutation = '_'.join(parts[1:])
        
        # Parse the fxout file
        results = parse_fxout_file(fxout_file)
        
        if results:
            for mutation_info, ddg in results:
                print(f"{fxout_file},{gene},{mutation},{ddg}")
        else:
            # If no results found, output a placeholder
            print(f"{fxout_file},{gene},{mutation},NA")

if __name__ == "__main__":
    main()