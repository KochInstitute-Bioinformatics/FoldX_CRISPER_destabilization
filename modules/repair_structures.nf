process REPAIR_STRUCTURES {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/repaired_structures", mode: 'copy'
    
    input:
    path genes_file
    val foldx_path
    path pdb_files
    
    output:
    path "*_Repair.pdb", emit: repaired_pdbs, optional: true
    
    when:
    genes_file.size() > 0  // Only run if there are genes to repair
    
    script:
    """
    echo "=== REPAIR_STRUCTURES DEBUG ==="
    echo "Available PDB files:"
    ls -la *.pdb
    
    # Use the correct FoldX executable name
    FOLDX_CMD="${foldx_path}"
    echo "Using FoldX command: \$FOLDX_CMD"
    
    # Test FoldX
    \$FOLDX_CMD --help || echo "FoldX help failed, but continuing..."
    
    # Read genes from file (only if file is not empty)
    if [[ -s "${genes_file}" ]]; then
        while IFS= read -r gene; do
            [[ -z "\$gene" ]] && continue  # Skip empty lines
            
            echo "Processing gene: \$gene"
            repaired_file="\${gene}_Repair.pdb"
            
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
                    ls -la *.pdb || echo "No PDB files found"
                fi
            else
                echo "ERROR: PDB file not found for gene: \$gene"
            fi
        done < ${genes_file}
    else
        echo "No genes to repair - genes file is empty"
    fi
    
    echo "Final repaired structures:"
    ls -la *_Repair.pdb || echo "No repaired structures found"
    """
}