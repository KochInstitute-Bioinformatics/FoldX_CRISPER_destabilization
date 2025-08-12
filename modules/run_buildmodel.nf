process RUN_BUILDMODEL {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/foldx_results", mode: 'copy'
    
    input:
    path mutation_files
    path repaired_pdbs
    val foldx_path
    path pdb_files
    
    output:
    path "*/*.fxout", emit: foldx_results  // Changed to capture all .fxout files with directory structure
    
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
        
        # Determine output directory name
        if [[ \$mutation == "WT" ]]; then
            out_dir="\${gene}_WT_BuildModel"
        else
            out_dir="\${gene}_\${mutation}_BuildModel"
        fi
        
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
        
        # Run FoldX BuildModel
        cd \$out_dir
        echo "  → Running FoldX BuildModel in \$out_dir"
        
        if ${foldx_path} --command=BuildModel \\
            --pdb=\${gene}_Repair.pdb \\
            --mutant-file=individual_list.txt \\
            --numberOfRuns=${params.number_of_runs}; then
            
            # Check for the correct Average file pattern
            if ls Average_*.fxout 1> /dev/null 2>&1; then
                echo "  ✓ BuildModel successful"
                echo "  → Average files found:"
                ls -la Average_*.fxout
                
                # Rename files to include mutation info to avoid collisions
                for fxout_file in *.fxout; do
                    if [[ \$fxout_file != *"\${mutation}"* ]]; then
                        new_name="\${gene}_\${mutation}_\${fxout_file}"
                        mv "\$fxout_file" "\$new_name"
                        echo "  → Renamed \$fxout_file to \$new_name"
                    fi
                done
                
                success_count=\$((success_count + 1))
            else
                echo "  ✗ BuildModel completed but no Average_*.fxout produced"
                echo "  → Files in output directory:"
                ls -la *.fxout
            fi
        else
            echo "  ✗ FoldX BuildModel failed with exit code \$?"
            echo "  → Files in output directory:"
            ls -la
        fi
        
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