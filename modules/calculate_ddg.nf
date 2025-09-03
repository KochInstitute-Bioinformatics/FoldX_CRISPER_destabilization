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
    echo "Available files:"
    ls -la
    
    echo "Available Dif files:"
    ls -la Dif*.fxout 2>/dev/null || echo "No Dif*.fxout files found"
    
    # Parse only Dif files to get the mutation results
    python3 ${parse_fxout_script} Dif*.fxout > final_ddG_results.csv
    
    echo "Final results created:"
    echo "Number of lines in results:"
    wc -l final_ddG_results.csv
    echo "Contents:"
    cat final_ddG_results.csv
    """
}