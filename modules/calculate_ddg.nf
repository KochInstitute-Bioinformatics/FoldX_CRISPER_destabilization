process CALCULATE_DDG {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/final_results", mode: 'copy'
    
    input:
    path foldx_results_dir
    path original_csv
    
    output:
    path "final_ddG_results.csv", emit: final_results
    
    script:
    """
    echo "=== CALCULATE_DDG DEBUG INFO ==="
    echo "FoldX results directory: ${foldx_results_dir}"
    echo "Original CSV: ${original_csv}"
    
    # List the structure of foldx results
    echo "FoldX results structure:"
    find ${foldx_results_dir} -name "*.fxout" -type f
    
    # Run the parsing script
    parse_energies.py ${foldx_results_dir} ${original_csv} final_ddG_results.csv
    
    # Debug: show the final results
    echo "Final results:"
    cat final_ddG_results.csv
    """
}