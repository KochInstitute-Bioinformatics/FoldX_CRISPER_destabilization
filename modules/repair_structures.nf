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
    
    # Check if repaired_structures_dir is provided
    REPAIRED_DIR="${params.repaired_structures_dir ?: ''}"
    echo "Repaired structures directory: \$REPAIRED_DIR"
    
    # Use the correct FoldX executable name
    FOLDX_CMD="foldx_20251231"
    echo "Using FoldX command: \$FOLDX_CMD"
    
    # Test FoldX (only if we need to use it)
    if [[ -z "\$REPAIRED_DIR" ]]; then
        \$FOLDX_CMD --help || echo "FoldX help failed, but continuing..."
    fi
    
    # Read genes from file
    while IFS= read -r gene; do
        echo "Processing gene: \$gene"
        
        repaired_file="\${gene}_Repair.pdb"
        
        # First, check if we have a pre-repaired structure in the specified directory
        if [[ -n "\$REPAIRED_DIR" && -f "\$REPAIRED_DIR/\$repaired_file" ]]; then
            echo "Found pre-repaired structure: \$REPAIRED_DIR/\$repaired_file"
            cp "\$REPAIRED_DIR/\$repaired_file" ./
            echo "Copied pre-repaired structure: \$repaired_file"
            continue
        fi
        
        # If not found in cache, check if already exists in current directory
        if [[ -f "\$repaired_file" ]]; then
            echo "Already repaired in current directory: \$repaired_file"
            continue
        fi
        
        # Find corresponding PDB file for repair
        pdb_file="\${gene}.pdb"
        if [[ -f "\$pdb_file" ]]; then
            echo "Found PDB file: \$pdb_file"
            echo "Running FoldX RepairPDB for \$gene (no cached version found)"
            
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
    
    echo "Final repaired structures:"
    ls -la *_Repair.pdb || echo "No repaired structures found"
    """
}