process COMBINE_REPLICATES {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/combined_results", mode: 'copy'
    
    input:
    tuple val(gene), val(mutation), path(fxout_files)
    
    output:
    tuple val(gene), val(mutation), path("*_combined_raw.fxout"), emit: combined_results
    tuple val(gene), val(mutation), path("*_summary_stats.txt"), emit: summary_stats
    
    script:
    def is_wt = mutation == "WT"
    def base_name = is_wt ? "${gene}_WT" : "${gene}_${mutation}"
    def combined_raw = "${base_name}_combined_raw.fxout"
    def summary_stats = "${base_name}_summary_stats.txt"
    
    """
    echo "=== Combining replicates for ${gene} ${mutation} ===" 
    echo "Found files: ${fxout_files}"
    
    # Initialize combined raw file
    echo "FoldX 5.1 (2011)" > ${combined_raw}
    echo "by the FoldX Consortium" >> ${combined_raw}
    echo "Jesper Borg, Frederic Rousseau, Joost Schymkowitz," >> ${combined_raw}
    echo "Luis Serrano and Francois Stricher" >> ${combined_raw}
    echo "------------------------------------------------------" >> ${combined_raw}
    echo "" >> ${combined_raw}
    echo "PDB file analysed: batch" >> ${combined_raw}
    echo "Output type: BuildModel - Combined Replicates" >> ${combined_raw}
    
    # Find and process Raw files
    raw_files=()
    for fxout in ${fxout_files}; do
        if [[ \$fxout == *"Raw"* ]]; then
            raw_files+=(\$fxout)
        fi
    done
    
    echo "Processing \${#raw_files[@]} raw files..."
    
    if [ \${#raw_files[@]} -gt 0 ]; then
        # Get header from first raw file
        first_raw=\${raw_files[0]}
        grep "^Pdb" \$first_raw >> ${combined_raw}
        
        # Combine all raw data
        for raw_file in "\${raw_files[@]}"; do
            echo "# From replicate file: \$raw_file" >> ${combined_raw}
            tail -n +10 \$raw_file | grep -E "^working_structure|^WT_working_structure" >> ${combined_raw}
        done
        
        # Create summary statistics
        echo "=== Summary Statistics for ${gene} ${mutation} ===" > ${summary_stats}
        echo "Number of replicates: \${#raw_files[@]}" >> ${summary_stats}
        echo "Files processed:" >> ${summary_stats}
        for raw_file in "\${raw_files[@]}"; do
            echo "  - \$raw_file" >> ${summary_stats}
        done
        echo "" >> ${summary_stats}
        
        # Calculate basic statistics from raw data
        python3 -c "
import sys
import numpy as np
from collections import defaultdict

# Read all energy values
energies = defaultdict(list)
structure_types = set()

for raw_file in ['${fxout_files.join("', '")}']:
    if 'Raw' not in raw_file:
        continue
        
    try:
        with open(raw_file, 'r') as f:
            lines = f.readlines()
        
        for line in lines:
            if line.startswith('working_structure') or line.startswith('WT_working_structure'):
                parts = line.strip().split()
                if len(parts) >= 2:
                    structure_name = parts[0]
                    try:
                        total_energy = float(parts[1])
                        
                        # Determine structure type
                        if structure_name.startswith('WT_'):
                            struct_type = 'WT'
                        else:
                            struct_type = 'Mutant'
                        
                        energies[struct_type].append(total_energy)
                        structure_types.add(struct_type)
                    except (ValueError, IndexError):
                        continue
    except Exception as e:
        print(f'Error processing {raw_file}: {e}', file=sys.stderr)

# Write statistics
with open('${summary_stats}', 'a') as f:
    f.write('Energy Statistics:\\n')
    f.write('=' * 50 + '\\n')
    
    for struct_type in sorted(structure_types):
        if struct_type in energies and len(energies[struct_type]) > 0:
            values = np.array(energies[struct_type])
            f.write(f'\\n{struct_type} Structures:\\n')
            f.write(f'  Count: {len(values)}\\n')
            f.write(f'  Mean: {np.mean(values):.3f}\\n')
            f.write(f'  Std Dev: {np.std(values):.3f}\\n')
            f.write(f'  Min: {np.min(values):.3f}\\n')
            f.write(f'  Max: {np.max(values):.3f}\\n')
            f.write(f'  Range: {np.max(values) - np.min(values):.3f}\\n')
    
    # Calculate ddG if both WT and Mutant present
    if 'WT' in energies and 'Mutant' in energies and len(energies['WT']) > 0 and len(energies['Mutant']) > 0:
        wt_mean = np.mean(energies['WT'])
        mut_mean = np.mean(energies['Mutant'])
        ddg = mut_mean - wt_mean
        
        f.write(f'\\nΔΔG Calculation:\\n')
        f.write(f'  WT Mean Energy: {wt_mean:.3f}\\n')
        f.write(f'  Mutant Mean Energy: {mut_mean:.3f}\\n')
        f.write(f'  ΔΔG (Mutant - WT): {ddg:.3f}\\n')
        
        if ddg > 1.0:
            f.write(f'  Interpretation: Destabilizing (ΔΔG > 1.0)\\n')
        elif ddg < -1.0:
            f.write(f'  Interpretation: Stabilizing (ΔΔG < -1.0)\\n')
        else:
            f.write(f'  Interpretation: Neutral (-1.0 ≤ ΔΔG ≤ 1.0)\\n')
"
        
    else
        echo "No raw files found to process!" >> ${summary_stats}
        echo "Available files: ${fxout_files}" >> ${summary_stats}
    fi
    
    echo "Created combined file: ${combined_raw}"
    echo "Created summary file: ${summary_stats}"
    
    # List final outputs
    ls -la *_combined_raw.fxout *_summary_stats.txt
    """
}