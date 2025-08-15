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
        
        # Parse filename patterns:
        # WT files: GENE_WT_Average_*.fxout, GENE_WT_Raw_*.fxout
        # Mutant files: GENE_MUTATION_Average_*.fxout, GENE_MUTATION_Raw_*.fxout
        parts = filename.replace('.fxout', '').split('_')
        
        if len(parts) >= 3:
            gene = parts[0]
            
            if parts[1] == 'WT':
                # WT file
                mutation = 'WT'
                file_type = parts[2]  # Should be 'Average', 'Raw', etc.
            else:
                # Mutant file
                mutation = parts[1]
                file_type = parts[2]  # Should be 'Average', 'Raw', etc.
            
            key = f"{gene}_{mutation}"
            if key not in file_groups:
                file_groups[key] = {'gene': gene, 'mutation': mutation, 'files': []}
            
            file_groups[key]['files'].append({
                'path': fxout_file,
                'type': file_type,
                'filename': filename,
                'is_wt': (mutation == 'WT')
            })
    
    print(f"File groups found: {list(file_groups.keys())}")
    
    # Group by gene to match WT with mutants
    gene_groups = {}
    for key, group in file_groups.items():
        gene = group['gene']
        if gene not in gene_groups:
            gene_groups[gene] = {'wt': None, 'mutants': []}
        
        if group['mutation'] == 'WT':
            gene_groups[gene]['wt'] = group
        else:
            gene_groups[gene]['mutants'].append(group)
    
    print(f"Gene groups: {list(gene_groups.keys())}")
    
    results = []
    detailed_results = []
    
    def parse_foldx_energy_file(file_path, file_type):
        \"\"\"Parse FoldX energy file and return energy values\"\"\"
        energies = []
        
        try:
            with open(file_path, 'r') as f:
                lines = f.readlines()
            
            print(f"    Parsing {file_path} ({len(lines)} lines)")
            
            # Find energy data lines
            for i, line in enumerate(lines):
                line = line.strip()
                if line and not line.startswith('#') and not line.startswith('FoldX') and '\\t' in line:
                    parts = line.split('\\t')
                    if len(parts) >= 2:
                        pdb_name = parts[0]
                        try:
                            # For Average files, skip SD column
                            if file_type == 'Average' and len(parts) >= 3:
                                total_energy = float(parts[2])  # Skip SD column
                            else:
                                total_energy = float(parts[1])
                            
                            energies.append({
                                'pdb_name': pdb_name,
                                'total_energy': total_energy
                            })
                            print(f"      {pdb_name}: {total_energy}")
                        except (ValueError, IndexError):
                            continue
            
            print(f"    Extracted {len(energies)} energy values")
            return energies
            
        except Exception as e:
            print(f"    Error parsing {file_path}: {e}")
            return []
    
    # Process each gene
    for gene, gene_data in gene_groups.items():
        print(f"\\n=== Processing gene: {gene} ===")
        
        wt_group = gene_data['wt']
        mutant_groups = gene_data['mutants']
        
        if not wt_group:
            print(f"  ✗ No WT data found for {gene}")
            continue
        
        if not mutant_groups:
            print(f"  ✗ No mutant data found for {gene}")
            continue
        
        # Get WT energies
        print(f"  → Processing WT data")
        wt_energies = []
        
        # Look for Average files first, then Raw files
        wt_average_files = [f for f in wt_group['files'] if f['type'] == 'Average']
        wt_raw_files = [f for f in wt_group['files'] if f['type'] == 'Raw']
        
        wt_files_to_use = wt_average_files if wt_average_files else wt_raw_files
        
        for wt_file in wt_files_to_use:
            print(f"    Processing WT file: {wt_file['filename']}")
            energies = parse_foldx_energy_file(wt_file['path'], wt_file['type'])
            wt_energies.extend([e['total_energy'] for e in energies])
        
        if not wt_energies:
            print(f"  ✗ No WT energies found for {gene}")
            continue
        
        wt_avg = np.mean(wt_energies)
        wt_std = np.std(wt_energies) if len(wt_energies) > 1 else 0
        print(f"  WT energies: {wt_energies}")
        print(f"  WT average: {wt_avg:.3f} ± {wt_std:.3f}")
        
        # Process each mutant
        for mutant_group in mutant_groups:
            mutation = mutant_group['mutation']
            print(f"  → Processing mutant: {mutation}")
            
            mutant_energies = []
            
            # Look for Average files first, then Raw files
            mut_average_files = [f for f in mutant_group['files'] if f['type'] == 'Average']
            mut_raw_files = [f for f in mutant_group['files'] if f['type'] == 'Raw']
            
            mut_files_to_use = mut_average_files if mut_average_files else mut_raw_files
            
            for mut_file in mut_files_to_use:
                print(f"    Processing mutant file: {mut_file['filename']}")
                energies = parse_foldx_energy_file(mut_file['path'], mut_file['type'])
                mutant_energies.extend([e['total_energy'] for e in energies])
            
            if not mutant_energies:
                print(f"    ✗ No mutant energies found for {gene}_{mutation}")
                continue
            
            mut_avg = np.mean(mutant_energies)
            mut_std = np.std(mutant_energies) if len(mutant_energies) > 1 else 0
            ddg_avg = mut_avg - wt_avg
            
            print(f"    Mutant energies: {mutant_energies}")
            print(f"    Mutant average: {mut_avg:.3f} ± {mut_std:.3f}")
            print(f"    ΔΔG: {ddg_avg:.3f}")
            
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
            max_len = max(len(wt_energies), len(mutant_energies))
            for i in range(max_len):
                wt_e = wt_energies[i % len(wt_energies)]
                mut_e = mutant_energies[i % len(mutant_energies)]
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