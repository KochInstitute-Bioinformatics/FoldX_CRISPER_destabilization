#!/usr/bin/env python3
"""
Parse mutation CSV file and generate individual FoldX mutation files.
"""
import csv
import re
import sys
import os

def parse_mutation(mutation_str):
    """Parse mutation string like 'E1932K' into components"""
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
            first_line = csvfile.readline().strip()
            csvfile.seek(0)
            print(f"CSV header: {first_line}")
            
            reader = csv.DictReader(csvfile)
            for row_num, row in enumerate(reader, 1):
                try:
                    if 'Gene' in row and 'Mutation' in row:
                        gene = row['Gene'].strip()
                        mutation = row['Mutation'].strip()
                        
                        try:
                            wt_aa, position, mut_aa = parse_mutation(mutation)
                        except ValueError as e:
                            print(f"Row {row_num}: Error parsing mutation {mutation}: {e}")
                            continue
                    else:
                        print("Error: Expected columns 'Gene' and 'Mutation'")
                        print(f"Found columns: {list(row.keys())}")
                        sys.exit(1)
                    
                    genes.add(gene)
                    
                    # Only generate files for actual mutations (not WT)
                    if wt_aa != mut_aa:
                        # Correct filename format: individual_list_GENE_MUTATION.txt
                        filename = f"individual_list_{gene}_{mutation}.txt"
                        
                        # Create FoldX mutation format: WT_AA,CHAIN,POSITION,MUT_AA;
                        with open(filename, 'w') as f:
                            f.write(f"{wt_aa}{chain}{position}{mut_aa};\n")
                        
                        print(f"Generated mutation file: {filename}")
                        mutation_count += 1
                    else:
                        print(f"Row {row_num}: Skipping WT entry: {gene} {wt_aa},{position},{mut_aa}")
                        
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
        
        # Verify files were created
        print(f"\nVerifying created files:")
        for filename in os.listdir('.'):
            if filename.startswith('individual_list_') and filename.endswith('.txt'):
                print(f"  - {filename}")
        
    except Exception as e:
        print(f"Error writing genes file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()