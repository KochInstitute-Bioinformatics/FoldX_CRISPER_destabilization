process RUN_BUILDMODEL {
    publishDir "${params.outdir}/foldx_results", mode: 'copy'
    
    input:
    tuple val(gene), val(mutation), path(mutation_file), path(repaired_pdb)
    val foldx_path
    val number_of_runs
    
    output:
    tuple val(gene), val(mutation), path("*${gene}_${mutation}*"), emit: foldx_results
    
    script:
    def mutation_filename = mutation_file.name
    """
    echo "=== RUN_BUILDMODEL ==="
    echo "Gene: ${gene}, Mutation: ${mutation}"
    echo "Working directory: \$(pwd)"
    echo "Files available:"
    ls -la
    
    echo "Mutation file content:"
    cat ${mutation_file}
    
    # Run FoldX BuildModel directly with the staged files
    echo "Running FoldX BuildModel..."
    echo "Command: ${foldx_path} --command=BuildModel --pdb=${repaired_pdb} --mutant-file=${mutation_filename} --numberOfRuns=${number_of_runs}"
    
    ${foldx_path} --command=BuildModel \\
        --pdb=${repaired_pdb} \\
        --mutant-file=${mutation_filename} \\
        --numberOfRuns=${number_of_runs}
    
    echo "FoldX exit code: \$?"
    echo "Files after FoldX run:"
    ls -la
    
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
    """
}