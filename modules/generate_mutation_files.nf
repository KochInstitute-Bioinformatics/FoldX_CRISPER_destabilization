process GENERATE_MUTATION_FILES {
    publishDir "${params.outdir}/mutation_files", mode: 'copy'
    
    input:
    path mutation_csv
    val chain
    path parse_script
    
    output:
    path "*.individual_list.txt", emit: mutation_files
    path "genes.txt", emit: genes
    
    script:
    """
    echo "=== GENERATE_MUTATION_FILES DEBUG ==="
    echo "Processing mutation CSV: ${mutation_csv}"
    echo "Chain: ${chain}"
    
    # Use the parse_mutations.py script passed as input
    python3 ${parse_script} ${mutation_csv} ${chain}

    echo "Generated mutation files:"
    ls -la *.individual_list.txt || echo "No mutation files generated"
    
    echo "Genes file content:"
    cat genes.txt
    """
}