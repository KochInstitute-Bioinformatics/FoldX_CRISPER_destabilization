#!/usr/bin/env python3

import pandas as pd
import sys
import os
import glob

def read_average_fxout(path):
    """Read energy from Average.fxout file"""
    if not os.path.exists(path):
        return None
    
    with open(path, 'r') as f:
        lines = f.readlines()
    
    for line in lines:
        if line.startswith('Pdb'):
            continue  # skip header
        parts = line.strip().split('\t')
        try:
            return float(parts[1])  # Total Energy column
        except:
            return None
    return None

def calculate_ddg(foldx_results_dir, original_csv, output_file):
    """Calculate ΔΔG from FoldX results"""
    
    # Load original data
    df = pd.read_csv(original_csv)
    results = []
    
    # Find all Average.fxout files
    fxout_files = glob.glob(os.path.join(foldx_results_dir, "*/Average.fxout"))
    
    # Create lookup for energies
    energies = {}
    for fxout_file in fxout_files:
        dir_name = os.path.basename(os.path.dirname(fxout_file))
        energy = read_average_fxout(fxout_file)
        energies[dir_name] = energy
    
    # Calculate ΔΔG for each mutation
    for _, row in df.iterrows():
        gene = row['Gene']
        mutation = row['Mutation'].strip()
        
        mut_key = f"{gene}_{mutation}"
        wt_key = f"{gene}_WT"
        
        mut_energy = energies.get(mut_key)
        wt_energy = energies.get(wt_key)
        
        ddg = mut_energy - wt_energy if mut_energy is not None and wt_energy is not None else None
        
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
        print("Usage: parse_energies.py <foldx_results_dir> <original.csv> <output.csv>")
        sys.exit(1)
    
    calculate_ddg(sys.argv[1], sys.argv[2], sys.argv[3])