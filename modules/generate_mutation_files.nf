process GENERATE_MUTATION_FILES {
    conda "conda-forge::pandas=2.0.3"
    
    publishDir "${params.outdir}/mutation_files", mode: 'copy'
    
    input:
    path mutation_csv
    val chain
    
    output:
    path "*.individual_list.txt", emit: mutation_files
    path "genes.txt", emit: genes
    
    script:
    """
    generate_mutations.py ${mutation_csv} ${chain}
    """
}