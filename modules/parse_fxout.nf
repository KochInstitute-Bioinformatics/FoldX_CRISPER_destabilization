process PARSE_FXOUT {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/parsed_results", mode: 'copy'
    
    input:
    path foldx_results
    
    output:
    path "parsed_results.csv", emit: parsed_results
    
    script:
    """
    parse_fxout.py ${foldx_results}
    """
}