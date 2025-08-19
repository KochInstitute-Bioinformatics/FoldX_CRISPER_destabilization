process GENERATE_MUTATION_FILES {
    container "docker://jupyter/scipy-notebook:latest"
    
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

        # Create WT files for each gene
        for gene in genes:
            wt_filename = f"{gene}_WT.individual_list.txt"
            
            # For WT, we need to create "self-mutations" for all positions that will be mutated
            gene_mutations = df[df['Gene'] == gene]
            wt_mutations = []
            
            for _, row in gene_mutations.iterrows():
                mutation = str(row['Mutation']).strip()
                if mutation == 'WT' or mutation == 'nan':
                    continue
                    
                # Parse mutation to get original AA and position
                pattern = r'([A-Z])(\\d+)([A-Z])'
                match = re.match(pattern, mutation)
                if match:
                    original_aa = match.group(1)
                    position = match.group(2)
                    # For WT, mutate to itself: R273R instead of R273H
                    # CORRECT FoldX format: RA273R; (no commas!)
                    wt_mutation = f"{original_aa}${chain}{position}{original_aa};"
                    wt_mutations.append(wt_mutation)
            
            # Write WT file
            with open(wt_filename, 'w') as f:
                for wt_mut in wt_mutations:
                    f.write(wt_mut + "\\n")
            
            print(f"Created WT file: {wt_filename} with {len(wt_mutations)} self-mutations")

        # Process each mutation
        mutation_count = 0
        for _, row in df.iterrows():
            gene = str(row['Gene']).strip()
            mutation = str(row['Mutation']).strip()

            print(f"Processing {gene}: {mutation}")

            # Skip WT or empty mutations
            if mutation in ['WT', 'nan', '']:
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

            # Create FoldX mutation format: OriginalAA + Chain + Position + NewAA + semicolon
            # CORRECT format: RA273H; (NO COMMAS!)
            foldx_mutation = f"{original_aa}${chain}{position}{new_aa};"
            print(f"  FoldX format: {foldx_mutation}")

            # Write individual mutation file
            filename = f"{gene}_{mutation}.individual_list.txt"
            with open(filename, 'w') as f:
                f.write(foldx_mutation + "\\n")

            print(f"  Created: {filename}")
            mutation_count += 1

        print(f"\\nCreated {mutation_count} mutation files successfully!")
        
        # List all created files and show their contents
        import glob
        all_files = glob.glob("*.individual_list.txt")
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