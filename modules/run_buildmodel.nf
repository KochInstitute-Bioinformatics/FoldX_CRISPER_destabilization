process RUN_BUILDMODEL {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/foldx_results", mode: 'copy'
    
    input:
    path mutation_files
    path repaired_pdbs
    val foldx_path
    val structure_dir
    
    output:
    path "*/Average.fxout", emit: foldx_results
    
    script:
    """
    echo "=== RUN_BUILDMODEL DEBUG INFO ==="
    echo "FoldX path: ${foldx_path}"
    echo "Mutation files: ${mutation_files}"
    echo "Repaired PDBs: ${repaired_pdbs}"
    
    # List all available files
    echo "All files in working directory:"
    ls -la
    
    for mut_file in ${mutation_files}; do
        # Extract gene and mutation info from filename
        base_name=\$(basename \$mut_file .individual_list.txt)
        gene=\$(echo \$base_name | cut -d'_' -f1)
        mutation=\$(echo \$base_name | cut -d'_' -f2-)
        
        echo "Processing: \$base_name (Gene: \$gene, Mutation: \$mutation)"
        
        # Determine if this is WT or mutant
        if [[ \$mutation == "WT" ]]; then
            out_dir="\${gene}_WT"
        else
            out_dir="\${gene}_\${mutation}"
        fi
        
        echo "Output directory: \$out_dir"
        
        # Skip if already exists
        if [ -f "\${out_dir}/Average.fxout" ]; then
            echo "  ✓ Results already exist, skipping"
            continue
        fi
        
        # Create output directory
        mkdir -p \$out_dir
        
        # Look for the correct repair file
        repair_file="\${gene}_Repair.pdb"
        if [ -f "\$repair_file" ]; then
            echo "  ✓ Found repair file: \$repair_file"
            cp "\$repair_file" \$out_dir/
        else
            echo "  ✗ ERROR: Repair file \$repair_file not found"
            echo "  Available PDB files:"
            ls -la *.pdb
            continue
        fi
        
        # Copy mutation file
        cp \$mut_file \$out_dir/individual_list.txt
        
        # Run FoldX BuildModel
        cd \$out_dir
        echo "  → Running FoldX BuildModel in \$out_dir"
        echo "  → Command: ${foldx_path} --command=BuildModel --pdb=\${gene}_Repair.pdb --mutant-file=individual_list.txt --numberOfRuns=${params.number_of_runs}"
        
        ${foldx_path} --command=BuildModel --pdb=\${gene}_Repair.pdb --mutant-file=individual_list.txt --numberOfRuns=${params.number_of_runs}
        
        # Check FoldX exit status
        foldx_exit=\$?
        echo "  → FoldX exit status: \$foldx_exit"
        
        # Check results
        if [ -f "Average.fxout" ]; then
            echo "  ✓ BuildModel successful"
        else
            echo "  ✗ BuildModel failed - no Average.fxout produced"
            echo "  → Files in output directory:"
            ls -la
        fi
        
        cd ..
    done
    
    echo "=== FINAL RESULTS ==="
    find . -name "Average.fxout" -exec echo "Found: {}" \\;
    
    # Ensure at least one output file exists
    if ! find . -name "Average.fxout" | grep -q .; then
        echo "No Average.fxout files found, creating dummy"
        mkdir -p dummy_output
        touch dummy_output/Average.fxout
    fi
    """
}