process REPAIR_STRUCTURES {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/repaired_structures", mode: 'copy'
    
    input:
    path genes_file
    val foldx_path
    path pdb_files
    
    output:
    path "*_Repair.pdb", emit: repaired_pdbs
    
    script:
    """
    echo "=== REPAIR_STRUCTURES DEBUG ==="
    echo "Available PDB files:"
    ls -la *.pdb
    
    # Use the correct FoldX executable name
    FOLDX_CMD="foldx_20251231"
    
    echo "Using FoldX command: \$FOLDX_CMD"
    
    # Test FoldX
    \$FOLDX_CMD --help || echo "FoldX help failed, but continuing..."
    
    # Read genes from file
    while IFS= read -r gene; do
        echo "Processing gene: \$gene"
        
        # Find corresponding PDB file
        pdb_file="\${gene}.pdb"
        if [[ -f "\$pdb_file" ]]; then
            echo "Found PDB file: \$pdb_file"
            
            # Check if already repaired
            if [[ -f "\${gene}_Repair.pdb" ]]; then
                echo "Already repaired: \${gene}_Repair.pdb"
                continue
            fi
            
            # Run FoldX RepairPDB
            echo "Running FoldX RepairPDB for \$gene"
            \$FOLDX_CMD --command=RepairPDB --pdb=\$pdb_file
            
            # Check if repair was successful
            if [[ -f "\${gene}_Repair.pdb" ]]; then
                echo "Successfully repaired: \${gene}_Repair.pdb"
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
    
    echo "Final repaired structures:"
    ls -la *_Repair.pdb || echo "No repaired structures found"
    """
}