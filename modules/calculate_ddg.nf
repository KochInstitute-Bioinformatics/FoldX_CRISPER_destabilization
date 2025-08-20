process CALCULATE_DDG {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/final_results", mode: 'copy', overwrite: true
    
    input:
    path foldx_results
    path original_csv
    path parse_energies_script
    path parse_fxout_script
    
    output:
    path "final_ddG_results.csv", emit: final_results
    path "*.fxout", emit: fxout_files, optional: true
    path "parsed_*.csv", emit: parsed_files, optional: true
    
    script:
    """
    echo "=== CALCULATE_DDG using bin scripts ==="
    
    # List all input files
    echo "All input files:"
    ls -la
    
    # Copy all .fxout files to final_results (they will be published automatically)
    echo "Copying .fxout files..."
    if ls *.fxout 1> /dev/null 2>&1; then
        cp *.fxout ./
        echo "Copied .fxout files to final_results"
    else
        echo "No .fxout files found to copy"
    fi
    
    # Parse each .fxout file using parse_fxout.py
    echo "Parsing .fxout files..."
    for fxout_file in *.fxout; do
        if [[ -f "\$fxout_file" ]]; then
            base_name=\$(basename "\$fxout_file" .fxout)
            output_csv="parsed_\${base_name}.csv"
            echo "Parsing \$fxout_file -> \$output_csv"
            python3 ${parse_fxout_script} "\$fxout_file" "\$output_csv"
        fi
    done
    
    # Calculate ΔΔG values using parse_energies.py
    echo "Calculating ΔΔG values..."
    python3 ${parse_energies_script} . ${original_csv} final_ddG_results.csv
    
    echo "Processing completed:"
    echo "- .fxout files copied to final_results"
    echo "- Individual .fxout files parsed to CSV format"
    echo "- ΔΔG calculations completed using parse_energies.py"
    
    # List final outputs
    echo "Final output files:"
    ls -la *.csv *.fxout 2>/dev/null || echo "No output files found"
    """
}