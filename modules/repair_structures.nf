process REPAIR_STRUCTURES {
    container "docker://bumproo/foldx5"
    publishDir "${params.outdir}/repaired_structures", mode: 'copy'
    
    input:
    path genes_file
    val foldx_path
    path pdb_files  // Now receives staged PDB files
    
    output:
    path "*_Repair.pdb", emit: repaired_pdbs
    
    script:
    """
    echo "=== REPAIR_STRUCTURES DEBUG INFO ==="
    echo "Genes file: ${genes_file}"
    echo "FoldX path: ${foldx_path}"
    echo "Staged PDB files:"
    ls -la *.pdb
    
    # Test FoldX executable
    if ! command -v ${foldx_path} &> /dev/null; then
        echo "ERROR: FoldX executable not found at ${foldx_path}"
        exit 1
    fi
    
    echo "=== PROCESSING GENES ==="
    success_count=0
    
    while IFS= read -r gene; do
        gene=\$(echo "\$gene" | tr -d '\\r\\n')
        echo "Processing gene: \$gene"
        
        # Look for PDB file (now staged in working directory)
        if [ -f "\${gene}.pdb" ]; then
            echo "  ✓ Found PDB file: \${gene}.pdb"
            
            # Run FoldX RepairPDB
            echo "  → Running FoldX RepairPDB for \$gene"
            ${foldx_path} --command=RepairPDB --pdb=\${gene}.pdb
            
            # Check if repair was successful
            if [ -f "\${gene}_Repair.pdb" ]; then
                echo "  ✓ Repair successful for \$gene"
                success_count=\$((success_count + 1))
            else
                echo "  ✗ ERROR: Repair failed for \$gene"
                echo "  → Available files after FoldX run:"
                ls -la \${gene}* || echo "    No gene-related files found"
            fi
        else
            echo "  ✗ ERROR: PDB file not found: \${gene}.pdb"
            echo "  → Available PDB files:"
            ls -la *.pdb
        fi
        echo ""
    done < ${genes_file}
    
    echo "=== REPAIR SUMMARY ==="
    echo "Successfully repaired \$success_count structures"
    ls -la *_Repair.pdb 2>/dev/null || echo "No repair files produced"
    
    if [ \$success_count -eq 0 ]; then
        echo "ERROR: No structures were successfully repaired"
        exit 1
    fi
    """
}