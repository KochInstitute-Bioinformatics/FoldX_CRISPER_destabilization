process CALCULATE_DDG {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/final_results", mode: 'copy', overwrite: true
    
    input:
    path foldx_results
    path original_csv
    
    output:
    path "final_ddG_results.csv", emit: final_results
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import glob
    import os
    import numpy as np
    
    print("=== SIMPLIFIED DDG CALCULATION ===")
    
    # List all input files
    print("All input files:")
    for f in os.listdir('.'):
        print(f"  {f}")
    
    # Read original mutations
    df_orig = pd.read_csv('${original_csv}')
    print("Original mutations:")
    print(df_orig)
    
    # Find all .fxout files
    all_fxout_files = glob.glob('*.fxout')
    print(f"Found {len(all_fxout_files)} .fxout files:")
    for f in all_fxout_files:
        print(f"  {f}")
    
    def parse_foldx_average_file(file_path):
        \"\"\"Parse FoldX Average.fxout file and return energy value\"\"\"
        try:
            with open(file_path, 'r') as f:
                lines = f.readlines()
            
            # Skip header lines and find data
            for line in lines:
                line = line.strip()
                if line and not line.startswith('FoldX') and not line.startswith('by') and not line.startswith('Jesper') and not line.startswith('Luis') and not line.startswith('---'):
                    if 'PDB file analysed' in line or 'Output type' in line:
                        continue
                    
                    # Look for lines with tab-separated data
                    if '\\t' in line:
                        parts = line.split('\\t')
                        if len(parts) >= 2:
                            try:
                                # Second column should be total energy
                                total_energy = float(parts[1])
                                return total_energy
                            except ValueError:
                                continue
            return None
        except Exception as e:
            print(f"Error parsing {file_path}: {e}")
            return None
    
    results = []
    
    # Group files by gene and mutation
    file_groups = {}
    for fxout_file in all_fxout_files:
        filename = os.path.basename(fxout_file)
        print(f"Processing: {filename}")
        
        # Parse filename: GENE_MUTATION_TYPE.fxout or GENE_WT_TYPE.fxout
        if 'Average' in filename:
            parts = filename.replace('.fxout', '').split('_')
            if len(parts) >= 3:
                gene = parts[0]
                if parts[1] == 'WT':
                    mutation = 'WT'
                else:
                    mutation = parts[1]
                
                key = f"{gene}_{mutation}"
                if key not in file_groups:
                    file_groups[key] = {'gene': gene, 'mutation': mutation, 'files': []}
                file_groups[key]['files'].append(fxout_file)
    
    print(f"File groups: {list(file_groups.keys())}")
    
    # Process each gene separately
    genes = df_orig['Gene'].unique()
    
    for gene in genes:
        print(f"\\n=== Processing gene: {gene} ===")
        
        # Find WT energy for this gene
        wt_key = f"{gene}_WT"
        wt_energy = None
        
        if wt_key in file_groups:
            wt_files = file_groups[wt_key]['files']
            if wt_files:
                wt_energy = parse_foldx_average_file(wt_files[0])
                print(f"WT energy for {gene}: {wt_energy}")
        
        if wt_energy is None:
            print(f"WARNING: No WT energy found for {gene}")
            continue
        
        # Process mutations for this gene
        gene_mutations = df_orig[df_orig['Gene'] == gene]
        
        for _, row in gene_mutations.iterrows():
            mutation = row['Mutation']
            mut_key = f"{gene}_{mutation}"
            
            print(f"  Processing mutation: {mutation}")
            
            if mut_key in file_groups:
                mut_files = file_groups[mut_key]['files']
                if mut_files:
                    mut_energy = parse_foldx_average_file(mut_files[0])
                    
                    if mut_energy is not None:
                        ddg = mut_energy - wt_energy
                        
                        result = {
                            'Gene': gene,
                            'Mutation': mutation,
                            'WT_energy': wt_energy,
                            'mutant_energy': mut_energy,
                            'ddG': ddg
                        }
                        results.append(result)
                        print(f"    WT: {wt_energy:.3f}, Mutant: {mut_energy:.3f}, ddG: {ddg:.3f}")
                    else:
                        print(f"    ERROR: Could not parse mutant energy")
                else:
                    print(f"    ERROR: No files found for {mut_key}")
            else:
                print(f"    ERROR: No file group found for {mut_key}")
    
    # Create results DataFrame
    if results:
        df_results = pd.DataFrame(results)
        
        # Merge with original data
        final_df = pd.merge(df_orig, df_results, on=['Gene', 'Mutation'], how='left')
        
        # Save results
        final_df.to_csv('final_ddG_results.csv', index=False)
        
        print("\\n=== FINAL RESULTS ===")
        print(final_df)
        print(f"Saved {len(final_df)} results to final_ddG_results.csv")
    else:
        print("ERROR: No results generated!")
        # Create empty file to avoid pipeline failure
        pd.DataFrame(columns=['Gene', 'Mutation', 'WT_energy', 'mutant_energy', 'ddG']).to_csv('final_ddG_results.csv', index=False)
    """
}