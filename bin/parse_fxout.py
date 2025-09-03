#!/usr/bin/env python3
"""
Enhanced parser for FoldX output files.
Extracts the first mutation result from Dif*.fxout files.
"""
import sys
import os
import re

def parse_dif_file(dif_file):
    """Parse a Dif*.fxout file and extract the first mutation's total energy value"""
    try:
        with open(dif_file, 'r') as f:
            lines = f.readlines()
        
        # Find the data section (after headers)
        data_started = False
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith('#') or line.startswith('FoldX') or line.startswith('by the') or line.startswith('Jesper') or line.startswith('Luis') or line.startswith('------'):
                continue
            
            # Skip the header line with column names
            if line.startswith('Pdb') and 'total energy' in line:
                data_started = True
                continue
            
            # Process data lines
            if data_started:
                # Split by tabs or multiple spaces
                parts = re.split(r'\s+', line)
                
                if len(parts) >= 2:
                    try:
                        pdb_name = parts[0]
                        total_energy = float(parts[1])
                        
                        # Return only the first mutation result (not the wild-type references)
                        # The first row typically contains the mutation, subsequent rows are references
                        return total_energy
                        
                    except (ValueError, IndexError):
                        continue
                        
    except Exception as e:
        print(f"Error parsing {dif_file}: {e}", file=sys.stderr)
    
    return None

def extract_gene_and_mutation_from_filename(filename):
    """Extract gene and mutation information from filename"""
    basename = os.path.basename(filename)
    
    # Remove file extensions
    basename = basename.replace('.fxout', '')
    
    # Try different patterns to extract gene and mutation
    patterns = [
        r'Dif_([^_]+)_([^_]+)_\1_\2',  # Dif_GENE_MUTATION_GENE_MUTATION pattern
        r'Dif_([^_]+)_([^_]+)',        # Dif_GENE_MUTATION pattern
        r'([^_]+)_([^_]+)_\1_\2',      # GENE_MUTATION_GENE_MUTATION pattern
        r'([^_]+)_([^_]+)',            # GENE_MUTATION pattern
    ]
    
    for pattern in patterns:
        match = re.search(pattern, basename)
        if match:
            gene = match.group(1)
            mutation = match.group(2)
            return gene, mutation
    
    # Fallback: try to find gene and mutation pattern separately
    # Look for gene names (common patterns)
    gene_match = re.search(r'(ROS1|TP53|BRCA1|BRCA2|EGFR|KRAS|PIK3CA|APC|PTEN)', basename, re.IGNORECASE)
    gene = gene_match.group(1).upper() if gene_match else "Unknown"
    
    # Look for mutation pattern (letter + numbers + letter)
    mutation_match = re.search(r'([A-Z]\d+[A-Z])', basename)
    mutation = mutation_match.group(1) if mutation_match else "Unknown"
    
    return gene, mutation

def main():
    if len(sys.argv) < 2:
        print("Usage: parse_fxout.py <fxout_files...>")
        sys.exit(1)
    
    print("Gene,Mutation,ddG")
    
    # Process only Dif files
    processed_mutations = set()
    
    for fxout_file in sys.argv[1:]:
        if not os.path.exists(fxout_file):
            continue
            
        basename = os.path.basename(fxout_file)
        
        # Only process Dif files
        if basename.startswith('Dif') and fxout_file.endswith('.fxout'):
            gene, mutation = extract_gene_and_mutation_from_filename(fxout_file)
            mutation_key = f"{gene}_{mutation}"
            
            # Skip if we've already processed this mutation
            if mutation_key in processed_mutations:
                continue
            
            ddg_value = parse_dif_file(fxout_file)
            
            if ddg_value is not None:
                print(f"{gene},{mutation},{ddg_value}")
            else:
                print(f"{gene},{mutation},NA")
            
            processed_mutations.add(mutation_key)

if __name__ == "__main__":
    main()