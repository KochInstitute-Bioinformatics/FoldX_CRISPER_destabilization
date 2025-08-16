process CALCULATE_DDG {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/final_results", mode: 'copy'

    input:
    path foldx_results
    path original_csv

    output:
    path "final_ddG_results.csv", emit: final_results
    path "detailed_runs_results.csv", emit: detailed_results

    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import glob
    import os
    import sys
    import numpy as np
    import re

    print("=== CALCULATE_DDG DEBUG INFO ===")
    print(f"Python version: {sys.version}")
    print(f"Working directory: {os.getcwd()}")
    print(f"Number of runs parameter: ${params.number_of_runs}")

    # Create a results directory and organize files
    os.makedirs('foldx_results_dir', exist_ok=True)

    # Copy all .fxout files to the results directory
    foldx_files = "${foldx_results}".split()
    print(f"Input files: {foldx_files}")

    for file in foldx_files:
        if file.endswith('.fxout'):
            print(f"Copying {file}")
            os.system(f"cp '{file}' foldx_results_dir/")

    # List what we have
    print("Files in foldx_results_dir:")
    for f in sorted(os.listdir('foldx_results_dir')):
        print(f"  {f}")

    # Read original mutations
    try:
        df_orig = pd.read_csv('${original_csv}')
        print("Original mutations:")
        print(df_orig)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        sys.exit(1)

    # Find all .fxout files
    all_fxout_files = glob.glob('foldx_results_dir/*.fxout')
    print(f"Found .fxout files: {len(all_fxout_files)}")

    # Group files by gene and mutation
    file_groups = {}
    for fxout_file in all_fxout_files:
        filename = os.path.basename(fxout_file)
        print(f"Processing filename: {filename}")
        
        # Parse filename: GENE_MUTATION_TYPE_GENE_Repair.fxout
        base_name = filename.replace('.fxout', '')
        parts = base_name.split('_')
        print(f"  Filename parts: {parts}")
        
        if len(parts) >= 3:
            gene = parts[0]
            mutation = parts[1]
            file_type = parts[2]  # Average, Raw, Dif, PdbList, etc.
            
            key = f"{gene}_{mutation}"
            if key not in file_groups:
                file_groups[key] = {'gene': gene, 'mutation': mutation, 'files': []}
            
            file_groups[key]['files'].append({
                'path': fxout_file,
                'type': file_type,
                'filename': filename
            })
            print(f"  → Grouped as: {key} (type: {file_type})")

    print(f"File groups found: {list(file_groups.keys())}")

    def parse_foldx_energy_file(file_path, file_type):
        \"\"\"Parse FoldX energy file and return separate WT and mutant energy values\"\"\"
        wt_energies = []
        mutant_energies = []
        
        try:
            with open(file_path, 'r') as f:
                lines = f.readlines()
            
            print(f"    Parsing {file_path} ({len(lines)} lines)")
            
            # Find energy data lines
            for i, line in enumerate(lines):
                line = line.strip()
                if not line or line.startswith('FoldX') or line.startswith('by the') or line.startswith('Jesper') or line.startswith('Luis') or line.startswith('---'):
                    continue
                
                # Skip header lines
                if 'PDB file analysed' in line or 'Output type' in line:
                    continue
                
                # Look for lines with energy data
                if '\\t' in line or (len(line.split()) > 2 and any(char.isdigit() or char == '.' or char == '-' for char in line)):
                    parts = re.split(r'\\s+|\\t+', line)
                    if len(parts) >= 2:
                        pdb_name = parts[0]
                        try:
                            # For Average files, the energy is usually in column 2 (after SD)
                            if file_type == 'Average' and len(parts) >= 3:
                                total_energy = float(parts[2])
                            else:
                                # For Raw files, energy is in column 1
                                total_energy = float(parts[1])
                            
                            # Determine if this is WT or mutant based on filename
                            if 'WT_' in pdb_name or pdb_name.startswith('WT'):
                                wt_energies.append({
                                    'pdb_name': pdb_name,
                                    'total_energy': total_energy
                                })
                                print(f"      WT {pdb_name}: {total_energy}")
                            else:
                                mutant_energies.append({
                                    'pdb_name': pdb_name,
                                    'total_energy': total_energy
                                })
                                print(f"      Mutant {pdb_name}: {total_energy}")
                                
                        except (ValueError, IndexError) as e:
                            print(f"      Skipping line (parse error): {line[:50]}...")
                            continue
            
            print(f"    Extracted {len(wt_energies)} WT and {len(mutant_energies)} mutant energy values")
            return wt_energies, mutant_energies
            
        except Exception as e:
            print(f"    Error parsing {file_path}: {e}")
            return [], []

    results = []
    detailed_results = []

    # Process each mutation group
    for key, group in file_groups.items():
        gene = group['gene']
        mutation = group['mutation']
        
        print(f"\\n=== Processing {gene}_{mutation} ===")
        
        # Find the best files to use (prefer Average, then Raw)
        average_files = [f for f in group['files'] if f['type'] == 'Average']
        raw_files = [f for f in group['files'] if f['type'] == 'Raw']
        files_to_use = average_files if average_files else raw_files
        
        if not files_to_use:
            print(f"  ✗ No suitable energy files found for {key}")
            continue
        
        all_wt_energies = []
        all_mutant_energies = []
        
        # Parse all relevant files
        for file_info in files_to_use:
            print(f"  → Processing file: {file_info['filename']}")
            wt_energies, mutant_energies = parse_foldx_energy_file(file_info['path'], file_info['type'])
            all_wt_energies.extend([e['total_energy'] for e in wt_energies])
            all_mutant_energies.extend([e['total_energy'] for e in mutant_energies])
        
        if not all_wt_energies:
            print(f"  ✗ No WT energies found for {key}")
            continue
            
        if not all_mutant_energies:
            print(f"  ✗ No mutant energies found for {key}")
            continue
        
        # Calculate statistics
        wt_avg = np.mean(all_wt_energies)
        wt_std = np.std(all_wt_energies) if len(all_wt_energies) > 1 else 0
        mut_avg = np.mean(all_mutant_energies)
        mut_std = np.std(all_mutant_energies) if len(all_mutant_energies) > 1 else 0
        ddg_avg = mut_avg - wt_avg
        
        print(f"  WT energies ({len(all_wt_energies)}): {all_wt_energies}")
        print(f"  WT average: {wt_avg:.3f} ± {wt_std:.3f}")
        print(f"  Mutant energies ({len(all_mutant_energies)}): {all_mutant_energies}")
        print(f"  Mutant average: {mut_avg:.3f} ± {mut_std:.3f}")
        print(f"  ΔΔG: {ddg_avg:.3f}")
        
        # Store result
        result = {
            'Gene': gene,
            'Mutation': mutation,
            'WT_energy_avg': wt_avg,
            'WT_energy_std': wt_std,
            'mutant_energy_avg': mut_avg,
            'mutant_energy_std': mut_std,
            'ddG_avg': ddg_avg,
            'ddG_std': np.sqrt(wt_std**2 + mut_std**2),  # Error propagation
            'number_of_runs': ${params.number_of_runs}
        }
        results.append(result)
        
        # Store detailed results
        max_len = max(len(all_wt_energies), len(all_mutant_energies))
        for i in range(max_len):
            wt_e = all_wt_energies[i % len(all_wt_energies)]
            mut_e = all_mutant_energies[i % len(all_mutant_energies)]
            detailed_results.append({
                'Gene': gene,
                'Mutation': mutation,
                'Run': i + 1,
                'WT_energy': wt_e,
                'mutant_energy': mut_e,
                'ddG': mut_e - wt_e
            })

    print(f"\\nTotal results collected: {len(results)}")

    # Create results DataFrame
    if results:
        df_results = pd.DataFrame(results)
        print("\\nFinal Results DataFrame:")
        print(df_results)
        
        # Save averaged results
        df_results.to_csv('final_ddG_results.csv', index=False)
        print("Results saved to final_ddG_results.csv")
        
        # Save detailed results if available
        if detailed_results:
            df_detailed = pd.DataFrame(detailed_results)
            df_detailed.to_csv('detailed_runs_results.csv', index=False)
            print("Detailed results saved to detailed_runs_results.csv")
        else:
            # Create empty detailed results file
            pd.DataFrame(columns=['Gene', 'Mutation', 'Run', 'WT_energy', 'mutant_energy', 'ddG']).to_csv('detailed_runs_results.csv', index=False)
        
        # Show final results
        if os.path.exists('final_ddG_results.csv'):
            print("\\n=== FINAL RESULTS ===")
            with open('final_ddG_results.csv', 'r') as f:
                print(f.read())
    else:
        print("ERROR: No results to save!")
        # Create empty files to avoid pipeline failure
        pd.DataFrame(columns=['Gene', 'Mutation', 'WT_energy_avg', 'WT_energy_std', 'mutant_energy_avg', 'mutant_energy_std', 'ddG_avg', 'ddG_std', 'number_of_runs']).to_csv('final_ddG_results.csv', index=False)
        pd.DataFrame(columns=['Gene', 'Mutation', 'Run', 'WT_energy', 'mutant_energy', 'ddG']).to_csv('detailed_runs_results.csv', index=False)
        print("Created empty results files")
    """
}