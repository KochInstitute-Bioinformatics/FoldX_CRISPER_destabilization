#!/usr/bin/env python3
import pandas as pd
import sys
import os
import glob

def read_average_fxout(path):
    """Read energy from Average.fxout file"""
    if not os.path.exists(path):
        print(f"Warning: {path} does not exist")
        return None
    
    try:
        with open(path, 'r') as f:
            lines = f.readlines()
        
        for line in lines:
            if line.startswith('Pdb'):
                continue  # skip header
            parts = line.strip().split('\t')
            if len(parts) > 1:
                try:
                    return float(parts[1])  # Total Energy column
                except ValueError:
                    print(f"Warning: Could not parse energy from {path}: {parts[1]}")
                    return None
    except Exception as e:
        print(f"Error reading {path}: {e}")
        return None
    
    return None

def calculate_ddg(foldx_results_input, original_csv, output_file):
    """Calculate ΔΔG from FoldX results"""
    print(f"Input: {foldx_results_input}")
    print(f"Original CSV: {original_csv}")
    print(f"Output: {output_file}")
    
    # Load original data
    df = pd.read_csv(original_csv)
    results = []
    
    # Handle different input types
    if os.path.isdir(foldx_results_input):
        # Single directory
        search_pattern = os.path.join(foldx_results_input, "*/Average.fxout")
    else:
        # Multiple files/directories passed
        search_pattern = "**/Average.fxout"
    
    # Find all Average.fxout files
    fxout_files = glob.glob(search_pattern, recursive=True)
    print(f"Found {len(fxout_files)} Average.fxout files:")
    for f in fxout_files:
        print(f"  - {f}")
    
    # Create lookup for energies
    energies = {}
    for fxout_file in fxout_files:
        dir_name = os.path.basename(os.path.dirname(fxout_file))
        energy = read_average_fxout(fxout_file)
        energies[dir_name] = energy
        print(f"  {dir_name}: {energy}")
    
    # Calculate ΔΔG for each mutation
    for _, row in df.iterrows():
        gene = row['Gene']
        mutation = row['Mutation'].strip()
        
        mut_key = f"{gene}_{mutation}"
        wt_key = f"{gene}_WT"
        
        mut_energy = energies.get(mut_key)
        wt_energy = energies.get(wt_key)
        
        print(f"Processing {gene} {mutation}:")
        print(f"  WT key: {wt_key} -> {wt_energy}")
        print(f"  Mut key: {mut_key} -> {mut_energy}")
        
        ddg = None
        if mut_energy is not None and wt_energy is not None:
            ddg = mut_energy - wt_energy
        
        result = row.to_dict()
        result.update({
            'WT_energy': wt_energy,
            'mutant_energy': mut_energy,
            'ddG': ddg
        })
        results.append(result)
    
    # Save results
    final_df = pd.DataFrame(results)
    final_df.to_csv(output_file, index=False)
    print(f"✅ Final results saved to: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: parse_energies.py <foldx_results_dir> <original_csv> <output_file>")
        sys.exit(1)
    
    calculate_ddg(sys.argv[1], sys.argv[2], sys.argv[3])