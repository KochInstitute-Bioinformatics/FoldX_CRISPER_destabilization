process WRITE_MISSING_GENES {
    publishDir "${params.outdir}/final_results", mode: 'copy'
    
    input:
    val missing_genes_list

    output:
    path "missing_genes.txt", emit: missing_genes_file

    script:
    """
    echo "# Genes with missing structure files" > missing_genes.txt
    echo "# Generated on: \$(date)" >> missing_genes.txt
    echo "# Total missing genes: ${missing_genes_list.size()}" >> missing_genes.txt
    echo "" >> missing_genes.txt
    
    if [ ${missing_genes_list.size()} -gt 0 ]; then
        echo "Gene_Name" >> missing_genes.txt
        echo "${missing_genes_list.join('\n')}" >> missing_genes.txt
    else
        echo "No missing genes found - all genes had corresponding structure files." >> missing_genes.txt
    fi
    
    echo "" >> missing_genes.txt
    echo "# End of file" >> missing_genes.txt
    """
}