#!/usr/bin/env python3
"""
Parse mutation CSV file and generate individual FoldX mutation files.
"""

import csv
import re
import sys
import os
from pathlib import Path

def parse_mutation(mutation_str):
    """Parse mutation string like 'E1932K' into components"""
    # Match pattern: single letter + numbers + single letter
    match = re.match(r'^([A-Z])(\d+)([A-Z])$', mutation_str.strip())
    if match:
        return match.group(1), match.group(2), match.group(3)
    else:
        raise ValueError(f"Invalid mutation format: {mutation_str}")

def main():
    if len(sys.argv) != 3:
        print("Usage: parse_mutations.py <csv_file> <chain>")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    chain = sys.argv[2]
    
    print(f"Processing CSV file: {csv_file}")
    print(f"Chain: {chain}")
    
    genes = set()
    mutation_count = 0
    
    try:
        with open(csv_file, 'r') as csvfile:
            # Peek at the header to determine format
            first_line = csvfile.readline().strip()
            csvfile.seek(0)  # Reset to beginning
            
            print(f"CSV header: {first_line}")
            
            reader = csv.DictReader(csvfile)
            
            for row_num, row in enumerate(reader, 1):
                try:
                    # Handle different CSV formats
                    if 'gene' in row and 'position' in row and 'wt_aa' in row and 'mut_aa' in row:
                        # Detailed format: gene, position, wt_aa, mut_aa
                        gene = row['gene'].strip()
                        position = row['position'].strip()
                        wt_aa = row['wt_aa'].strip()
                        mut_aa = row['mut_aa'].strip()
                        
                    elif 'Gene' in row and 'Mutation' in row:
                        # Simple format: Gene, Mutation (like E1932K)
                        gene = row['Gene'].strip()
                        mutation = row['Mutation'].strip()
                        try:
                            wt_aa, position, mut_aa = parse_mutation(mutation)
                        except ValueError as e:
                            print(f"Row {row_num}: Error parsing mutation {mutation} for gene {gene}: {e}")
                            continue
                            
                    else:
                        print("Error: Unrecognized CSV format")
                        print("Expected columns: 'Gene,Mutation' or 'gene,position,wt_aa,mut_aa'")
                        print(f"Found columns: {list(row.keys())}")
                        sys.exit(1)
                    
                    genes.add(gene)
                    
                    # Only generate files for actual mutations (not WT)
                    if wt_aa != mut_aa:
                        mutation_name = f"{wt_aa}{position}{mut_aa}"
                        filename = f"{gene}_{mutation_name}.individual_list.txt"
                        
                        
                        print(f"Generated mutation file: {filename}")
                        mutation_count += 1
                    else:
                        print(f"Row {row_num}: Skipping WT entry: {gene}{wt_aa}{position}{mut_aa}")
                        
                except Exception as e:
                    print(f"Row {row_num}: Error processing row {row}: {e}")
                    continue
    
    except FileNotFoundError:
        print(f"Error: CSV file '{csv_file}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        sys.exit(1)
    
    # Write genes file
    try:
        with open('genes.txt', 'w') as f:
            for gene in sorted(genes):
                f.write(f"{gene}\n")
        
        print(f"\nSummary:")
        print(f"- Generated {mutation_count} mutation files")
        print(f"- Found {len(genes)} unique genes: {', '.join(sorted(genes))}")
        print(f"- Created genes.txt file")
        
    except Exception as e:
        print(f"Error writing genes file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()