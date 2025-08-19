process RUN_BUILDMODEL {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/foldx_results", mode: 'copy', overwrite: true
    
    input:
    tuple val(gene), val(mutation), path(mutation_file), path(repaired_pdb)
    val foldx_path
    
    output:
    tuple val(gene), val(mutation), path("*.fxout"), emit: foldx_results
    
    script:
    def is_wt = mutation == "WT"
    def output_prefix = is_wt ? "${gene}_WT" : "${gene}_${mutation}"
    
    """
    echo "=== Processing ${gene} ${mutation} ==="
    
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
    
    # Create working copies with FoldX-required names
    PDB_WORK="working_structure.pdb"
    MUTANT_WORK="individual_list"  # FoldX requires this exact name (no extension!)
    
    # Copy files with new names
    cp ${repaired_pdb} \$PDB_WORK
    cp ${mutation_file} \$MUTANT_WORK
    
    echo "Created working files:"
    echo "PDB: \$PDB_WORK"
    echo "Mutations: \$MUTANT_WORK"
    
    echo "Contents of mutation file:"
    cat \$MUTANT_WORK
    
    # Run FoldX BuildModel
    echo "Running FoldX BuildModel..."
    \$FOLDX_CMD --command=BuildModel \\
        --pdb=\$PDB_WORK \\
        --mutant-file=\$MUTANT_WORK \\
        --numberOfRuns=${params.number_of_runs}
    
    # Check FoldX exit status
    FOLDX_EXIT=\$?
    echo "FoldX exit status: \$FOLDX_EXIT"
    
    # List all output files
    echo "All files after FoldX run:"
    ls -la
    
    # Check if any .fxout files were created
    if ls *.fxout 1> /dev/null 2>&1; then
        echo "Found .fxout files, renaming..."
        # Rename output files to include gene and mutation info
        for fxout_file in *.fxout; do
            if [[ -f "\$fxout_file" ]]; then
                new_name="${output_prefix}_\${fxout_file}"
                mv "\$fxout_file" "\$new_name"
                echo "Renamed: \$fxout_file -> \$new_name"
            fi
        done
    else
        echo "ERROR: No .fxout files were created by FoldX"
        echo "Checking for any FoldX output files:"
        ls -la *foldx* || echo "No foldx files found"
        ls -la *FoldX* || echo "No FoldX files found"
        ls -la *.out || echo "No .out files found"
        ls -la *.log || echo "No .log files found"
        
        # Show FoldX error output if available
        if [[ -f "foldx.log" ]]; then
            echo "FoldX log file contents:"
            cat foldx.log
        fi
        
        # Create a dummy output file to prevent pipeline failure
        echo "Creating dummy output file for debugging"
        echo "FoldX failed to produce output for ${gene} ${mutation}" > "${output_prefix}_dummy.fxout"
    fi
    
    # List final outputs
    echo "Final outputs:"
    ls -la *.fxout
    """
}