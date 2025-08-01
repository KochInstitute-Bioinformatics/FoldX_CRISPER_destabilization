process CALCULATE_DDG {
    conda "conda-forge::pandas=2.0.3"
    
    publishDir "${params.outdir}/final_results", mode: 'copy'
    
    input:
    path foldx_results
    path original_csv
    
    output:
    path "final_ddG_results.csv", emit: final_results
    
    script:
    """
    parse_energies.py ${foldx_results} ${original_csv} final_ddG_results.csv
    """
}