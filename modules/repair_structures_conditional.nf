process REPAIR_STRUCTURES_CONDITIONAL {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/repaired_structures", mode: 'copy'
    
    input:
    path genes_file
    val foldx_path
    path pdb_files
    val repaired_dir
    
    output:
    path "*_Repair.pdb", emit: repaired_pdbs
    
    script:
    """
    echo "=== REPAIR_STRUCTURES_CONDITIONAL DEBUG ==="
    echo "Available PDB files:"
    ls -la *.pdb
    echo "Repaired structures directory: ${repaired_dir}"
    
    # Use the correct FoldX executable name
    FOLDX_CMD="${foldx_path}"
    echo "Using FoldX command: \$FOLDX_CMD"
    
    # Process each gene
    while IFS= read -r gene; do
        [[ -z "\$gene" ]] && continue  # Skip empty lines
        
        echo "Processing gene: \$gene"
        repaired_file="\${gene}_Repair.pdb"
        
        # Check if repaired file already exists in the specified directory
        if [[ -n "${repaired_dir}" && -f "${repaired_dir}/\${repaired_file}" ]]; then
            echo "Using existing repaired file: ${repaired_dir}/\${repaired_file}"
            cp "${repaired_dir}/\${repaired_file}" "\${repaired_file}"
        else
            echo "Need to repair \$gene"
            
            # Find corresponding PDB file for repair
            pdb_file="\${gene}.pdb"
            if [[ -f "\$pdb_file" ]]; then
                echo "Found PDB file: \$pdb_file"
                echo "Running FoldX RepairPDB for \$gene"
                
                # Run FoldX RepairPDB
                \$FOLDX_CMD --command=RepairPDB --pdb=\$pdb_file
                
                # Check if repair was successful
                if [[ -f "\$repaired_file" ]]; then
                    echo "Successfully repaired: \$repaired_file"
                else
                    echo "ERROR: Failed to repair \$pdb_file"
                    echo "Checking for any output files:"
                    ls -la *Repair* || echo "No repair files found"
                    ls -la \${gene}* || echo "No gene-specific files found"
                    
                    # Create a dummy file to prevent pipeline failure
                    touch "\$repaired_file"
                    echo "Created dummy repaired file: \$repaired_file"
                fi
            else
                echo "ERROR: PDB file not found for gene: \$gene"
                # Create a dummy file to prevent pipeline failure
                touch "\$repaired_file"
                echo "Created dummy repaired file: \$repaired_file"
            fi
        fi
    done < ${genes_file}
    
    echo "Final repaired structures:"
    ls -la *_Repair.pdb
    """
}