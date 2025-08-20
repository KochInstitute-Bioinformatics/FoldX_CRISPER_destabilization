process CALCULATE_DDG {
    publishDir "${params.outdir}/final_results", mode: 'copy'
    
    input:
    path foldx_files
    path parse_fxout_script
    
    output:
    path "final_ddG_results.csv", emit: final_results
    
    script:
    """
    echo "=== CALCULATE_DDG ==="
    echo "Processing FoldX output files..."
    echo "Available fxout files:"
    ls -la *.fxout
    
    # Parse all fxout files and create summary
    python3 ${parse_fxout_script} *.fxout > final_ddG_results.csv
    
    echo "Final results created:"
    echo "Number of lines in results:"
    wc -l final_ddG_results.csv
    echo "First 10 lines:"
    head -10 final_ddG_results.csv
    """
}