process RUN_BUILDMODEL {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/foldx_results", mode: 'copy'
    
    input:
    path mutation_files
    path repaired_pdbs
    val foldx_path
    path pdb_files
    
    output:
    path "*/*.fxout", emit: foldx_results
    
    script:
    """
    echo "=== RUN_BUILDMODEL DEBUG INFO ==="
    echo "FoldX path: ${foldx_path}"
    echo "Number of mutation files: \$(echo ${mutation_files} | wc -w)"
    echo "Number of repaired PDBs: \$(echo ${repaired_pdbs} | wc -w)"
    
    # Test FoldX executable
    if ! command -v ${foldx_path} &> /dev/null; then
        echo "ERROR: FoldX executable not found at ${foldx_path}"
        exit 1
    fi
    
    success_count=0
    
    for mut_file in ${mutation_files}; do
        # Extract gene and mutation info from filename
        base_name=\$(basename \$mut_file .individual_list.txt)
        gene=\$(echo \$base_name | cut -d'_' -f1)
        mutation=\$(echo \$base_name | cut -d'_' -f2-)
        
        echo "Processing: \$base_name (Gene: \$gene, Mutation: \$mutation)"
        
        # Skip WT files - we'll handle WT separately
        if [[ \$mutation == "WT" ]]; then
            echo "  → Skipping WT file (will be processed separately)"
            continue
        fi
        
        # Determine output directory name
        out_dir="\${gene}_\${mutation}_BuildModel"
        echo "Output directory: \$out_dir"
        
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
        
        cd \$out_dir
        
        echo "  → Step 1: Running FoldX Stability on WT structure"
        # First, run Stability on the WT structure to get baseline energy
        if ${foldx_path} --command=Stability \\
            --pdb=\${gene}_Repair.pdb \\
            --numberOfRuns=${params.number_of_runs}; then
            echo "  ✓ WT Stability calculation successful"
            
            # Rename WT stability files
            for fxout_file in *.fxout; do
                if [[ \$fxout_file == *"Stability"* ]]; then
                    new_name="\${gene}_WT_\${fxout_file}"
                    mv "\$fxout_file" "\$new_name"
                    echo "  → Renamed WT file: \$fxout_file to \$new_name"
                fi
            done
        else
            echo "  ✗ WT Stability calculation failed"
        fi
        
        echo "  → Step 2: Running FoldX BuildModel on mutant"
        # Then run BuildModel for the mutation
        if ${foldx_path} --command=BuildModel \\
            --pdb=\${gene}_Repair.pdb \\
            --mutant-file=individual_list.txt \\
            --numberOfRuns=${params.number_of_runs}; then
            
            echo "  ✓ BuildModel successful"
            
            # Rename mutant files to include mutation info
            for fxout_file in *.fxout; do
                if [[ \$fxout_file != *"\${gene}_WT_"* && \$fxout_file != *"\${mutation}"* ]]; then
                    new_name="\${gene}_\${mutation}_\${fxout_file}"
                    mv "\$fxout_file" "\$new_name"
                    echo "  → Renamed mutant file: \$fxout_file to \$new_name"
                fi
            done
            
            success_count=\$((success_count + 1))
        else
            echo "  ✗ FoldX BuildModel failed with exit code \$?"
        fi
        
        echo "  → Files in output directory:"
        ls -la *.fxout
        
        cd ..
    done
    
    echo "=== BUILDMODEL SUMMARY ==="
    echo "Successfully processed \$success_count mutations"
    find . -name "*.fxout" -exec echo "Found: {}" \\;
    
    # Exit with error if no BuildModel runs were successful
    if [ \$success_count -eq 0 ]; then
        echo "ERROR: No BuildModel runs were successful"
        exit 1
    fi
    """
}