#!/usr/bin/env python3

import pandas as pd
import sys

def parse_fxout(input_file, output_file):
    """Parse FoldX .fxout file to clean CSV"""
    
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    # Find header line
    header_line_index = 0
    for i, line in enumerate(lines):
        if line.startswith("Pdb|") or line.startswith("Pdb\t"):
            header_line_index = i
            break
    
    # Read data
    df = pd.read_csv(input_file, sep='|', skiprows=header_line_index)
    df.columns = [col.strip() for col in df.columns]
    
    # Save clean CSV
    df.to_csv(output_file, index=False)
    print(f"✅ Clean CSV saved to: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: parse_fxout.py <input.fxout> <output.csv>")
        sys.exit(1)
    
    parse_fxout(sys.argv[1], sys.argv[2])