process GENERATE_MUTATION_FILES {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/mutation_files", mode: 'copy'
    
    input:
    path mutation_csv
    val chain
    
    output:
    path "individual_list_*.txt", emit: mutation_files
    path "genes.txt", emit: genes
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import re
    import sys
    import traceback
    
    try:
        print("=== GENERATE_MUTATION_FILES DEBUG ===")
        print("Input CSV: ${mutation_csv}")
        print("Chain: ${chain}")
        
        # Read the mutation CSV
        df = pd.read_csv('${mutation_csv}')
        print(f"Read {len(df)} mutations from CSV")
        print("DataFrame columns:", list(df.columns))
        print("DataFrame contents:")
        print(df.head())
        
        # Get unique genes
        genes = df['Gene'].unique()
        print(f"Unique genes: {list(genes)}")
        
        # Write genes file
        with open('genes.txt', 'w') as f:
            for gene in genes:
                f.write(f"{gene}\\n")
        print("Created genes.txt")
        
        # Process each mutation (skip WT entries)
        mutation_count = 0
        for _, row in df.iterrows():
            gene = str(row['Gene']).strip()
            mutation = str(row['Mutation']).strip()
            print(f"Processing {gene}: {mutation}")
            
            # Skip WT or empty mutations since FoldX calculates WT by default
            if mutation in ['WT', 'nan', '']:
                print(f"  Skipping {mutation} - FoldX calculates WT by default")
                continue
                
            # Parse mutation (e.g., "R273H" -> original=R, position=273, new=H)
            pattern = r'([A-Z])(\\d+)([A-Z])'
            match = re.match(pattern, mutation)
            if not match:
                print(f"ERROR: Could not parse mutation {mutation}")
                continue
                
            original_aa = match.group(1)
            position = match.group(2)
            new_aa = match.group(3)
            print(f"  Parsed: {original_aa} at position {position} -> {new_aa}")
            
            # Create FoldX mutation format with individual_list prefix
            foldx_mutation = f"individual_list{original_aa}${chain},{position},{new_aa};"
            print(f"  FoldX format: {foldx_mutation}")
            
            # Write individual mutation file with correct naming format
            filename = f"individual_list_{gene}_{mutation}.txt"
            with open(filename, 'w') as f:
                f.write(foldx_mutation + "\\n")
            print(f"  Created: {filename}")
            mutation_count += 1
        
        print(f"\\nCreated {mutation_count} mutation files successfully!")
        print("Note: WT files not created - FoldX BuildModel calculates WT energy by default")
        
        # List all created files and show their contents
        import glob
        all_files = glob.glob("individual_list_*.txt")
        print(f"Total files created: {len(all_files)}")
        for f in all_files:
            print(f"\\n=== {f} ===")
            with open(f, 'r') as file:
                print(file.read().strip())
                
    except Exception as e:
        print(f"FATAL ERROR: {e}")
        traceback.print_exc()
        sys.exit(1)
    """
}