#!/usr/bin/env python3

import pandas as pd
import sys
import os

def generate_mutation_files(csv_file, chain):
    """Generate individual mutation files from CSV"""
    
    df = pd.read_csv(csv_file)
    genes = set()
    
    for _, row in df.iterrows():
        gene = row['Gene']
        mutation = row['Mutation'].strip()
        genes.add(gene)
        
        # Parse mutation
        wt_aa = mutation[0]
        pos = mutation[1:-1]
        mut_aa = mutation[-1]
        
        # Create mutant file
        mutant_filename = f'{gene}_{mutation}.individual_list.txt'
        with open(mutant_filename, 'w') as f:
            f.write(f"{wt_aa},{chain},{pos},{mut_aa};\n")
        
        # Create/append to WT file
        wt_filename = f'{gene}_WT.individual_list.txt'
        with open(wt_filename, 'a') as f:
            f.write(f"{wt_aa},{chain},{pos},{wt_aa};\n")
    
    # Save genes list
    with open('genes.txt', 'w') as f:
        for gene in genes:
            f.write(f"{gene}\n")
    
    print(f"✅ Generated mutation files for {len(genes)} genes")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: generate_mutations.py <mutations.csv> <chain>")
        sys.exit(1)
    
    generate_mutation_files(sys.argv[1], sys.argv[2])