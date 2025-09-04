process CONSOLIDATE_FAILURE_LOGS {
    publishDir "${params.outdir}/final_results", mode: 'copy'
    
    input:
    path missing_pdb_logs
    path missing_position_logs
    
    output:
    path "missing_pdbs.log", emit: missing_pdbs_summary
    path "missing_positions.log", emit: missing_positions_summary
    path "failure_summary.csv", emit: failure_summary
    
    script:
    """
    echo "=== CONSOLIDATE_FAILURE_LOGS ==="
    echo "Processing failure logs..."
    
    # Process missing PDB logs
    echo "# Missing PDB Files Report" > missing_pdbs.log
    echo "# Generated: \$(date)" >> missing_pdbs.log
    echo "# Format: Gene | Status | Reason | Timestamp" >> missing_pdbs.log
    echo "" >> missing_pdbs.log
    
    if ls missing_pdb_*.log 1> /dev/null 2>&1; then
        for log_file in missing_pdb_*.log; do
            if [[ -f "\$log_file" ]]; then
                echo "Processing \$log_file"
                gene=\$(grep "^Gene:" "\$log_file" | cut -d' ' -f2)
                status=\$(grep "^Status:" "\$log_file" | cut -d' ' -f2)
                reason=\$(grep "^Reason:" "\$log_file" | cut -d' ' -f2-)
                timestamp=\$(grep "^Timestamp:" "\$log_file" | cut -d' ' -f2-)
                echo "\$gene | \$status | \$reason | \$timestamp" >> missing_pdbs.log
            fi
        done
    else
        echo "No missing PDB files found - all genes had corresponding structure files." >> missing_pdbs.log
    fi
    
    # Process missing position logs
    echo "# Missing Position Report" > missing_positions.log
    echo "# Generated: \$(date)" >> missing_positions.log
    echo "# Format: Gene | Mutation | Status | Reason | Timestamp" >> missing_positions.log
    echo "" >> missing_positions.log
    
    if ls missing_position_*.log 1> /dev/null 2>&1; then
        for log_file in missing_position_*.log; do
            if [[ -f "\$log_file" ]]; then
                echo "Processing \$log_file"
                gene=\$(grep "^Gene:" "\$log_file" | cut -d' ' -f2)
                mutation=\$(grep "^Mutation:" "\$log_file" | cut -d' ' -f2)
                status=\$(grep "^Status:" "\$log_file" | cut -d' ' -f2)
                reason=\$(grep "^Reason:" "\$log_file" | cut -d' ' -f2-)
                timestamp=\$(grep "^Timestamp:" "\$log_file" | cut -d' ' -f2-)
                echo "\$gene | \$mutation | \$status | \$reason | \$timestamp" >> missing_positions.log
            fi
        done
    else
        echo "No missing positions found - all mutations were within structural coverage." >> missing_positions.log
    fi
    
    # Create CSV summary
    echo "Gene,Mutation,Failure_Type,Status,Reason,Timestamp" > failure_summary.csv
    
    # Add missing PDB entries
    if ls missing_pdb_*.log 1> /dev/null 2>&1; then
        for log_file in missing_pdb_*.log; do
            if [[ -f "\$log_file" ]]; then
                gene=\$(grep "^Gene:" "\$log_file" | cut -d' ' -f2)
                status=\$(grep "^Status:" "\$log_file" | cut -d' ' -f2)
                reason=\$(grep "^Reason:" "\$log_file" | cut -d' ' -f2- | sed 's/,/;/g')
                timestamp=\$(grep "^Timestamp:" "\$log_file" | cut -d' ' -f2-)
                echo "\$gene,ALL_MUTATIONS,MISSING_PDB,\$status,\$reason,\$timestamp" >> failure_summary.csv
            fi
        done
    fi
    
    # Add missing position entries
    if ls missing_position_*.log 1> /dev/null 2>&1; then
        for log_file in missing_position_*.log; do
            if [[ -f "\$log_file" ]]; then
                gene=\$(grep "^Gene:" "\$log_file" | cut -d' ' -f2)
                mutation=\$(grep "^Mutation:" "\$log_file" | cut -d' ' -f2)
                status=\$(grep "^Status:" "\$log_file" | cut -d' ' -f2)
                reason=\$(grep "^Reason:" "\$log_file" | cut -d' ' -f2- | sed 's/,/;/g')
                timestamp=\$(grep "^Timestamp:" "\$log_file" | cut -d' ' -f2-)
                echo "\$gene,\$mutation,MISSING_POSITION,\$status,\$reason,\$timestamp" >> failure_summary.csv
            fi
        done
    fi
    
    echo "Failure log consolidation complete."
    echo "Missing PDB summary:"
    wc -l missing_pdbs.log
    echo "Missing position summary:"
    wc -l missing_positions.log
    echo "CSV summary:"
    wc -l failure_summary.csv
    """
}