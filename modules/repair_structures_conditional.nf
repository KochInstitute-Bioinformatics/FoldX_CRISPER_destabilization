process REPAIR_STRUCTURES_CONDITIONAL {
    publishDir "${params.outdir}/repaired_structures", mode: 'copy'
    
    input:
    val gene
    val foldx_path
    path pdb_files
    val repaired_dir

    output:
    path "*_Repair.pdb", emit: repaired_pdbs, optional: true

    script:
    """
    echo "=== REPAIR_STRUCTURES_CONDITIONAL for gene: ${gene} ==="
    echo "FoldX path: ${foldx_path}"
    echo "Repaired dir: '${repaired_dir}'"
    echo "Available PDB files:"
    ls -la *.pdb 2>/dev/null || echo "No PDB files found"

    # Create repaired_structures_dir if it doesn't exist and is specified
    if [[ -n "${repaired_dir}" ]]; then
        mkdir -p "${repaired_dir}"
        echo "Ensured repaired structures directory exists: ${repaired_dir}"
    fi

    # Process the specific gene
    echo "Processing gene: ${gene}"
    repaired_file="${gene}_Repair.pdb"

    # Check if repaired file exists in provided directory
    if [[ -n "${repaired_dir}" ]]; then
        existing_file="${repaired_dir}/\${repaired_file}"
        echo "Looking for existing repaired file at: \$existing_file"
        if [[ -f "\$existing_file" && -s "\$existing_file" ]]; then
            echo "Found existing repaired file: \$existing_file"
            cp "\$existing_file" "\${repaired_file}"
            echo "Successfully using existing repaired file: \${repaired_file}"
            exit 0
        fi
    fi

    echo "Need to repair ${gene} from scratch"
    pdb_file="${gene}.pdb"
    
    if [[ -f "\$pdb_file" && -s "\$pdb_file" ]]; then
        echo "Running FoldX RepairPDB on \$pdb_file"
        ${foldx_path} --command=RepairPDB --pdb=\$pdb_file
        
        if [[ -f "\$repaired_file" && -s "\$repaired_file" ]]; then
            echo "Successfully repaired: \$repaired_file"
            # Store the newly repaired structure
            if [[ -n "${repaired_dir}" ]]; then
                cp "\$repaired_file" "${repaired_dir}/\${repaired_file}"
            fi
        else
            echo "ERROR: Repair failed for ${gene}"
            # Don't create empty file - let it fail and use optional: true
            exit 1
        fi
    else
        echo "WARNING: PDB file not found or empty: \$pdb_file - skipping gene ${gene}"
        # Don't create empty file - let it fail and use optional: true
        exit 1
    fi

    echo "Final repaired structure for ${gene}:"
    ls -la *_Repair.pdb 2>/dev/null || echo "No repaired structure created"
    """
}