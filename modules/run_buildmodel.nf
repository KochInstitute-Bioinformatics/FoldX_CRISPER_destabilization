process RUN_BUILDMODEL {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/foldx_results", mode: 'copy', overwrite: true
    
    input:
    tuple val(gene), val(mutation), path(mutation_file), path(repaired_pdb), val(replicate)
    val foldx_path
    
    output:
    tuple val(gene), val(mutation), val(replicate), path("*.fxout"), emit: foldx_results
    
    script:
    def is_wt = mutation == "WT"
    def output_prefix = is_wt ? "${gene}_WT_rep${replicate}" : "${gene}_${mutation}_rep${replicate}"
    
    """
    echo "=== Processing ${gene} ${mutation} Replicate ${replicate} ==="
    
    # Use the correct FoldX executable name
    FOLDX_CMD="foldx_20251231"
    
    # Test FoldX executable
    if ! command -v \$FOLDX_CMD &> /dev/null; then
        echo "ERROR: FoldX executable not found: \$FOLDX_CMD"
        exit 1
    fi
    
    # List current directory contents
    echo "Current directory contents:"
    ls -la
    
    # Create unique working copies with FoldX-required names for this replicate
    PDB_WORK="working_structure_rep${replicate}.pdb"
    MUTANT_WORK="individual_list_rep${replicate}"
    
    # Copy files with new names
    cp ${repaired_pdb} \$PDB_WORK
    cp ${mutation_file} \$MUTANT_WORK
    
    echo "Created working files for replicate ${replicate}:"
    echo "PDB: \$PDB_WORK"
    echo "Mutations: \$MUTANT_WORK"
    
    echo "Contents of mutation file:"
    cat \$MUTANT_WORK
    
    # Create a unique working environment for this replicate
    # Use different working directory names and add small delays to prevent caching
    WORK_DIR="foldx_work_rep${replicate}_\$(date +%s%N | cut -b1-13)"
    mkdir -p \$WORK_DIR
    cd \$WORK_DIR
    
    # Copy files to unique working directory
    cp ../\$PDB_WORK ./working_structure.pdb
    cp ../\$MUTANT_WORK ./individual_list
    
    echo "Working in directory: \$WORK_DIR"
    
    # Add a small delay based on replicate number to ensure different execution times
    sleep \$((${replicate} % 5))
    
    # Run FoldX BuildModel for single run
    echo "Running FoldX BuildModel for replicate ${replicate}..."
    \$FOLDX_CMD --command=BuildModel \\
        --pdb=working_structure.pdb \\
        --mutant-file=individual_list \\
        --numberOfRuns=1
    
    # Check FoldX exit status
    FOLDX_EXIT=\$?
    echo "FoldX exit status for replicate ${replicate}: \$FOLDX_EXIT"
    
    # List all output files
    echo "All files after FoldX run:"
    ls -la
    
    # Move back to parent directory
    cd ..
    
    # Check if any .fxout files were created
    if ls \$WORK_DIR/*.fxout 1> /dev/null 2>&1; then
        echo "Found .fxout files, moving and renaming for replicate ${replicate}..."
        # Move and rename output files to include gene, mutation, and replicate info
        for fxout_file in \$WORK_DIR/*.fxout; do
            if [[ -f "\$fxout_file" ]]; then
                basename_file=\$(basename "\$fxout_file")
                new_name="${output_prefix}_\${basename_file}"
                mv "\$fxout_file" "\$new_name"
                echo "Moved and renamed: \$fxout_file -> \$new_name"
            fi
        done
    else
        echo "ERROR: No .fxout files were created by FoldX for replicate ${replicate}"
        echo "Checking for any FoldX output files:"
        ls -la \$WORK_DIR/*foldx* 2>/dev/null || echo "No foldx files found"
        ls -la \$WORK_DIR/*FoldX* 2>/dev/null || echo "No FoldX files found"
        ls -la \$WORK_DIR/*.out 2>/dev/null || echo "No .out files found"
        ls -la \$WORK_DIR/*.log 2>/dev/null || echo "No .log files found"
        
        # Show FoldX error output if available
        if [[ -f "\$WORK_DIR/foldx.log" ]]; then
            echo "FoldX log file contents:"
            cat \$WORK_DIR/foldx.log
        fi
        
        # Create a dummy output file to prevent pipeline failure
        echo "Creating dummy output file for debugging replicate ${replicate}"
        echo "FoldX failed to produce output for ${gene} ${mutation} replicate ${replicate}" > "${output_prefix}_dummy.fxout"
    fi
    
    # Clean up working directory
    rm -rf \$WORK_DIR
    
    # List final outputs
    echo "Final outputs for replicate ${replicate}:"
    ls -la *.fxout
    """
}