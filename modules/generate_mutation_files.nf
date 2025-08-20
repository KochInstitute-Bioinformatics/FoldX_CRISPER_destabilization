process GENERATE_MUTATION_FILES {
    publishDir "${params.outdir}/mutation_files", mode: 'copy'
    
    input:
    path mutation_csv
    val chain
    
    output:
    path "*.individual_list.txt", emit: mutation_files
    path "genes.txt", emit: genes
    
    script:
    """
    echo "=== GENERATE_MUTATION_FILES DEBUG ==="
    echo "Processing mutation CSV: ${mutation_csv}"
    echo "Chain: ${chain}"
    
    # Read the CSV and generate individual mutation files
    python3 << 'EOF'
import csv
import os

genes = set()

with open('${mutation_csv}', 'r') as csvfile:
    reader = csv.DictReader(csvfile)
    
    for row in reader:
        gene = row['gene'].strip()
        position = row['position'].strip()
        wt_aa = row['wt_aa'].strip()
        mut_aa = row['mut_aa'].strip()
        
        genes.add(gene)
        
        # Only generate files for actual mutations (not WT)
        if wt_aa != mut_aa:
            mutation_name = f"{wt_aa},{position},{mut_aa}"
            filename = f"{gene}_{mutation_name}.individual_list.txt"
            
            with open(filename, 'w') as f:
                f.write(f"{wt_aa}{chain}{position}{mut_aa};\\n")
            
            print(f"Generated mutation file: {filename}")
        else:
            print(f"Skipping WT entry: {gene} {wt_aa}{position}{mut_aa}")

# Write genes file
with open('genes.txt', 'w') as f:
    for gene in sorted(genes):
        f.write(f"{gene}\\n")

print(f"Generated genes file with {len(genes)} unique genes")
EOF

    echo "Generated mutation files:"
    ls -la *.individual_list.txt || echo "No mutation files generated"
    
    echo "Genes file content:"
    cat genes.txt
    """
}