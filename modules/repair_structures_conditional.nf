process REPAIR_STRUCTURES_CONDITIONAL {
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
    echo "=== REPAIR_STRUCTURES_CONDITIONAL ==="
    echo "Genes file: ${genes_file}"
    echo "FoldX path: ${foldx_path}"
    echo "Repaired dir: '${repaired_dir}'"
    echo "Available PDB files:"
    ls -la *.pdb
    
    # Process each gene
    while IFS= read -r gene; do
        [[ -z "\$gene" ]] && continue
        echo "Processing gene: \$gene"
        
        repaired_file="\${gene}_Repair.pdb"
        
        # Check if repaired file exists in provided directory
        if [[ -n "${repaired_dir}" ]]; then
            # Try different possible paths for the existing repaired file
            existing_file="${repaired_dir}/\${repaired_file}"
            
            echo "Looking for existing repaired file at: \$existing_file"
            
            if [[ -f "\$existing_file" ]]; then
                echo "Found existing repaired file: \$existing_file"
                cp "\$existing_file" "\${repaired_file}"
                
                # Verify the copy was successful and file is not empty
                if [[ -s "\${repaired_file}" ]]; then
                    echo "Successfully using existing repaired file: \${repaired_file}"
                    continue
                else
                    echo "WARNING: Existing repaired file is empty, will repair from scratch"
                fi
            else
                echo "Existing repaired file not found at: \$existing_file"
                echo "Contents of repaired directory:"
                ls -la "${repaired_dir}/" || echo "Cannot list repaired directory"
            fi
        else
            echo "No repaired structures directory provided, will repair from scratch"
        fi
        
        echo "Need to repair \$gene from scratch"
        pdb_file="\${gene}.pdb"
        
        if [[ -f "\$pdb_file" ]]; then
            echo "Running FoldX RepairPDB on \$pdb_file"
            ${foldx_path} --command=RepairPDB --pdb=\$pdb_file
            
            if [[ -f "\$repaired_file" && -s "\$repaired_file" ]]; then
                echo "Successfully repaired: \$repaired_file"
            else
                echo "ERROR: Repair failed for \$gene"
                echo "Checking for any repair output files:"
                ls -la *Repair* || echo "No repair files found"
                ls -la \${gene}* || echo "No gene-specific files found"
                touch "\$repaired_file"  # Create empty file to prevent pipeline failure
            fi
        else
            echo "ERROR: PDB file not found: \$pdb_file"
            touch "\$repaired_file"
        fi
    done < ${genes_file}
    
    echo "Final repaired structures:"
    ls -la *_Repair.pdb
    """
}