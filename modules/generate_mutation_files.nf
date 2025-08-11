process GENERATE_MUTATION_FILES {
    container "docker://jupyter/scipy-notebook:latest"
    
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