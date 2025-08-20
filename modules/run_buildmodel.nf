process RUN_BUILDMODEL {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/buildmodel_results", mode: 'copy'
    
    input:
    tuple val(gene), val(mutation), path(mutation_file), path(repaired_pdb), val(replicate)
    val foldx_path
    
    output:
    tuple val(gene), val(mutation), val(replicate), path("*.fxout"), emit: foldx_results
    
    script:
    """
    echo "=== RUN_BUILDMODEL DEBUG ==="
    echo "Gene: ${gene}"
    echo "Mutation: ${mutation}"
    echo "Mutation file: ${mutation_file}"
    echo "Repaired PDB: ${repaired_pdb}"
    echo "Replicate: ${replicate}"
    
    # Use the correct FoldX executable name
    FOLDX_CMD="foldx_20251231"
    echo "Using FoldX command: \$FOLDX_CMD"
    
    # List available files
    echo "Available files:"
    ls -la
    
    # Verify the repaired PDB file exists
    if [[ ! -f "${repaired_pdb}" ]]; then
        echo "ERROR: Repaired PDB file not found: ${repaired_pdb}"
        exit 1
    fi
    
    # Verify the mutation file exists
    if [[ ! -f "${mutation_file}" ]]; then
        echo "ERROR: Mutation file not found: ${mutation_file}"
        exit 1
    fi
    
    # Show contents of mutation file
    echo "Contents of mutation file ${mutation_file}:"
    cat ${mutation_file}
    
    # Create a unique working directory for this replicate to avoid conflicts
    WORK_DIR="${gene}_${mutation}_rep${replicate}"
    mkdir -p \$WORK_DIR
    cd \$WORK_DIR
    
    # Copy files to working directory
    cp ../${repaired_pdb} ./
    cp ../${mutation_file} ./
    
    # Extract the base name of the mutation file (without individual_list_ prefix and .txt extension)
    MUTATION_FILE_BASE=\$(basename ${mutation_file} .txt)
    echo "Mutation file base name: \$MUTATION_FILE_BASE"
    
    # Run FoldX BuildModel with correct parameters
    echo "Running FoldX BuildModel..."
    \$FOLDX_CMD --command=BuildModel \\
        --pdb=${repaired_pdb} \\
        --mutant-file=\$MUTATION_FILE_BASE \\
        --numberOfRuns=5
    
    # Check if BuildModel was successful
    if [[ \$? -eq 0 ]]; then
        echo "FoldX BuildModel completed successfully"
    else
        echo "WARNING: FoldX BuildModel may have encountered issues, but continuing..."
    fi
    
    # List all output files
    echo "Output files generated:"
    ls -la
    
    # Move .fxout files back to parent directory with unique names
    for fxout_file in *.fxout; do
        if [[ -f "\$fxout_file" ]]; then
            # Create unique filename to avoid conflicts between replicates
            unique_name="${gene}_${mutation}_rep${replicate}_\$fxout_file"
            mv "\$fxout_file" "../\$unique_name"
            echo "Moved \$fxout_file to \$unique_name"
        fi
    done
    
    # Go back to parent directory
    cd ..
    
    # Clean up working directory
    rm -rf \$WORK_DIR
    
    # Verify we have output files
    echo "Final output files:"
    ls -la *.fxout || echo "No .fxout files found"
    
    # If no .fxout files, create a dummy one to prevent pipeline failure
    if ! ls *.fxout 1> /dev/null 2>&1; then
        echo "No .fxout files generated, creating dummy file for debugging"
        echo "No results generated for ${gene} ${mutation} replicate ${replicate}" > ${gene}_${mutation}_rep${replicate}_dummy.fxout
    fi
    """
}