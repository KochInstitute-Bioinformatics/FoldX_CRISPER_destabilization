#!/usr/bin/env python3
"""
Alternative CSV processing script for FoldX mutations.
"""

import csv
import re
import sys
import os

def parse_simple_mutation(mutation_str):
    """Parse simple mutation format like 'E1932K'"""
    match = re.match(r'^([A-Z])(\d+)([A-Z])$', mutation_str.strip())
    if match:
        return match.group(1), match.group(2), match.group(3)
    return None, None, None

def main():
    if len(sys.argv) != 3:
        print("Usage: process_csv.py <csv_file> <chain>")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    chain = sys.argv[2]
    
    genes = set()
    
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            # Try different column name variations
            gene = None
            mutation = None
            
            # Check for different possible column names
            for gene_col in ['Gene', 'gene', 'GENE']:
                if gene_col in row:
                    gene = row[gene_col].strip()
                    break
            
            for mut_col in ['Mutation', 'mutation', 'MUTATION']:
                if mut_col in row:
                    mutation = row[mut_col].strip()
                    break
            
            if not gene or not mutation:
                print(f"Warning: Could not find gene/mutation columns in row: {row}")
                continue
            
            genes.add(gene)
            
            # Parse mutation
            wt_aa, position, mut_aa = parse_simple_mutation(mutation)
            
            if wt_aa and position and mut_aa and wt_aa != mut_aa:
                filename = f"{gene}_{wt_aa},{position},{mut_aa}.individual_list.txt"
                with open(filename, 'w') as f:
                    f.write(f"{wt_aa},{chain},{position},{mut_aa};\n")
                print(f"Created: {filename}")
    
    # Write genes file
    with open('genes.txt', 'w') as f:
        for gene in sorted(genes):
            f.write(f"{gene}\n")
    
    print(f"Processed {len(genes)} genes")

if __name__ == "__main__":
    main()