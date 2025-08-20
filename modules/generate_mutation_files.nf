process GENERATE_MUTATION_FILES {
    publishDir "${params.outdir}/mutation_files", mode: 'copy'
    
    input:
    path mutation_csv
    val chain
    path parse_script
    
    output:
    path "individual_list_*.txt", emit: mutation_files
    path "genes.txt", emit: genes
    
    script:
    """
    echo "=== GENERATE_MUTATION_FILES ==="
    echo "Processing: ${mutation_csv}"
    echo "Chain: ${chain}"
    
    python3 ${parse_script} ${mutation_csv} ${chain}
    
    echo "Files created:"
    ls -la individual_list_*.txt
    echo "Genes:"
    cat genes.txt
    """
}