process CHECK_REPAIRED_FILES {
    input:
    path genes_file
    val repaired_dir
    
    output:
    path "existing_repaired.txt", emit: existing_files
    path "genes_to_repair.txt", emit: genes_to_repair
    
    script:
    """
    echo "=== CHECKING FOR EXISTING REPAIRED FILES ==="
    
    # Initialize output files
    touch existing_repaired.txt
    touch genes_to_repair.txt
    
    if [[ -n "${repaired_dir}" && -d "${repaired_dir}" ]]; then
        echo "Checking repaired structures directory: ${repaired_dir}"
        
        while IFS= read -r gene; do
            [[ -z "\$gene" ]] && continue  # Skip empty lines
            
            repaired_file="${repaired_dir}/\${gene}_Repair.pdb"
            if [[ -f "\$repaired_file" ]]; then
                echo "Found existing repaired file: \$repaired_file"
                echo "\$repaired_file" >> existing_repaired.txt
            else
                echo "Need to repair: \$gene"
                echo "\$gene" >> genes_to_repair.txt
            fi
        done < ${genes_file}
    else
        echo "No repaired structures directory provided or directory doesn't exist"
        echo "All genes need repair"
        cp ${genes_file} genes_to_repair.txt
    fi
    
    echo "Summary:"
    echo "Existing repaired files: \$(wc -l < existing_repaired.txt)"
    echo "Genes needing repair: \$(wc -l < genes_to_repair.txt)"
    """
}