process GENERATE_MUTATION_FILES {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/mutation_files", mode: 'copy'
    
    input:
    path mutation_csv
    val chain
    
    output:
    path "*.individual_list.txt", emit: mutation_files
    path "genes.txt", emit: genes
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import re
    
    print("=== GENERATE_MUTATION_FILES DEBUG ===")
    print("Input CSV: ${mutation_csv}")
    print("Chain: ${chain}")
    
    # Read the mutation CSV
    df = pd.read_csv('${mutation_csv}')
    print(f"Read {len(df)} mutations from CSV")
    print("DataFrame contents:")
    print(df)
    
    # Get unique genes
    genes = df['Gene'].unique()
    print(f"Unique genes: {list(genes)}")
    
    # Write genes file
    with open('genes.txt', 'w') as f:
        for gene in genes:
            f.write(f"{gene}\\n")
    print("Created genes.txt")
    
    # Process each mutation
    for _, row in df.iterrows():
        gene = row['Gene']
        mutation = row['Mutation']
        
        print(f"Processing {gene}: {mutation}")
        
        # Skip WT mutations
        if mutation == 'WT':
            wt_filename = f"{gene}_WT.individual_list.txt"
            with open(wt_filename, 'w') as f:
                f.write("")  # Empty file for WT
            print(f"Created WT file: {wt_filename}")
            continue
        
        # Parse mutation (e.g., "R273H" -> original=R, position=273, new=H)
        match = re.match(r'([A-Z])(\\d+)([A-Z])', mutation)
        if not match:
            print(f"ERROR: Could not parse mutation {mutation}")
            continue
            
        original_aa = match.group(1)
        position = match.group(2)
        new_aa = match.group(3)
        
        print(f"  Parsed: {original_aa} at position {position} -> {new_aa}")
        
        # Create FoldX mutation format: OriginalAA + Chain + Position + NewAA + semicolon
        # Format from documentation: RA273H; (NO COMMAS!)
        foldx_mutation = f"{original_aa}${chain}{position}{new_aa};"
        print(f"  FoldX format: {foldx_mutation}")
        
        # Write individual mutation file
        filename = f"{gene}_{mutation}.individual_list.txt"
        with open(filename, 'w') as f:
            f.write(foldx_mutation + "\\n")
        
        print(f"  Created: {filename}")
    
    print("\\nAll mutation files created successfully!")
    """
}