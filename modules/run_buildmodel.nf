process RUN_BUILDMODEL {
    publishDir "${params.outdir}/foldx_results", mode: 'copy'
    
    input:
    tuple val(gene), val(mutation), path(mutation_file), path(repaired_pdb)
    val foldx_path
    val number_of_runs

    output:
    tuple val(gene), val(mutation), path("*${gene}_${mutation}*"), emit: foldx_results, optional: true

    script:
    """
    echo "=== RUN_BUILDMODEL ==="
    echo "Gene: ${gene}, Mutation: ${mutation}"
    echo "Working directory: \$(pwd)"
    echo "Files available:"
    ls -la

    echo "Mutation file content:"
    cat ${mutation_file}

    # Check if the PDB file exists and is not empty
    if [[ ! -f "${repaired_pdb}" || ! -s "${repaired_pdb}" ]]; then
        echo "ERROR: Repaired PDB file is missing or empty: ${repaired_pdb}"
        exit 1
    fi

    # Run FoldX BuildModel with error handling
    echo "Running FoldX BuildModel..."
    echo "Command: ${foldx_path} --command=BuildModel --pdb=${repaired_pdb} --mutant-file=${mutation_file} --numberOfRuns=${number_of_runs}"

    # Capture FoldX output and check for specific errors
    if ${foldx_path} --command=BuildModel \\
        --pdb=${repaired_pdb} \\
        --mutant-file=${mutation_file} \\
        --numberOfRuns=${number_of_runs} 2>&1 | tee foldx_output.log; then
        
        foldx_exit_code=\${PIPESTATUS[0]}
        echo "FoldX exit code: \$foldx_exit_code"
        
        # Check if the mutation was actually performed
        if grep -q "Specified residue not found" foldx_output.log; then
            echo "WARNING: Mutation ${mutation} in gene ${gene} - residue position not found in structure"
            echo "This likely means the mutation position is outside the structural coverage"
            
            # Create a summary file for this failed mutation
            cat > "FAILED_${gene}_${mutation}_summary.txt" << EOF
Gene: ${gene}
Mutation: ${mutation}
Error: Specified residue not found in structure
Reason: The mutation position likely exceeds the structural coverage of the PDB file
Status: SKIPPED
EOF
            
            # Don't fail the process - just skip this mutation
            echo "Skipping mutation ${mutation} for gene ${gene} due to structural limitations"
            exit 0
            
        elif grep -q "no mutations performed" foldx_output.log; then
            echo "WARNING: No mutations were performed for ${mutation} in gene ${gene}"
            
            # Create a summary file for this failed mutation
            cat > "FAILED_${gene}_${mutation}_summary.txt" << EOF
Gene: ${gene}
Mutation: ${mutation}
Error: No mutations performed
Status: SKIPPED
EOF
            
            exit 0
        else
            echo "FoldX completed successfully"
        fi
    else
        echo "ERROR: FoldX command failed"
        exit 1
    fi

    echo "Files after FoldX run:"
    ls -la

    # Only proceed with renaming if we have actual output files
    if ls *.fxout 1> /dev/null 2>&1; then
        # Rename output files to include mutation information to avoid collisions
        echo "Renaming output files to include mutation info..."

        # Rename .fxout files
        for file in *.fxout; do
            if [[ -f "\$file" ]]; then
                # Extract the base name and add mutation info
                base_name=\$(echo "\$file" | sed 's/_${gene}_Repair\\.fxout//')
                new_name="\${base_name}_${gene}_${mutation}.fxout"
                mv "\$file" "\$new_name"
                echo "Renamed \$file to \$new_name"
            fi
        done

        # Rename Dif files (these contain the total energy values we want)
        for file in Dif*.fxout; do
            if [[ -f "\$file" ]]; then
                # Add gene and mutation info to Dif files
                base_name=\$(echo "\$file" | sed 's/\\.fxout//')
                new_name="\${base_name}_${gene}_${mutation}.fxout"
                mv "\$file" "\$new_name"
                echo "Renamed \$file to \$new_name"
            fi
        done

        echo "Final output files:"
        ls -la *${gene}_${mutation}*
    else
        echo "No .fxout files generated - mutation likely failed"
    fi
    """
}