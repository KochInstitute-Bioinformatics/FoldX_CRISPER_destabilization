#!/usr/bin/env python3
import os
import glob
import sys

def debug_foldx_files(results_dir):
    """Debug FoldX output files to understand their structure"""
    
    print(f"=== DEBUGGING FOLDX OUTPUT IN {results_dir} ===")
    
    # Find all .fxout files
    fxout_files = glob.glob(f"{results_dir}/**/*.fxout", recursive=True)
    
    print(f"Found {len(fxout_files)} .fxout files:")
    
    for i, fxout_file in enumerate(fxout_files):
        print(f"\n--- File {i+1}: {fxout_file} ---")
        
        try:
            with open(fxout_file, 'r') as f:
                lines = f.readlines()
            
            print(f"Total lines: {len(lines)}")
            
            # Show first 10 lines
            print("First 10 lines:")
            for j, line in enumerate(lines[:10]):
                print(f"  {j+1:2d}: {line.strip()}")
            
            # Count unique lines
            unique_lines = set(line.strip() for line in lines if line.strip())
            print(f"Unique lines: {len(unique_lines)}")
            
            # Look for energy values
            energy_lines = []
            for line in lines:
                if '\t' in line and not line.startswith('#'):
                    parts = line.strip().split('\t')
                    if len(parts) >= 2:
                        try:
                            float(parts[1])
                            energy_lines.append(line.strip())
                        except ValueError:
                            pass
            
            print(f"Lines with energy values: {len(energy_lines)}")
            if energy_lines:
                print("Sample energy lines:")
                for line in energy_lines[:3]:
                    print(f"  {line}")
                    
        except Exception as e:
            print(f"Error reading file: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python debug_foldx_output.py <results_directory>")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    debug_foldx_files(results_dir)