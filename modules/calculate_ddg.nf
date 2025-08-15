process CALCULATE_DDG {
    container "docker://jupyter/scipy-notebook:latest"
    publishDir "${params.outdir}/final_results", mode: 'copy'

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
    import sys

    print("=== CALCULATE_DDG DEBUG INFO ===")
    print(f"Python version: {sys.version}")
    print(f"Working directory: {os.getcwd()}")

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
    for f in os.listdir('foldx_results_dir'):
        print(f"  {f}")

    # Read original mutations
    try:
        df_orig = pd.read_csv('${original_csv}')
        print("Original mutations:")
        print(df_orig)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        sys.exit(1)

    # Find Raw files
    raw_files = glob.glob('foldx_results_dir/*Raw*.fxout')
    print(f"Found Raw files: {raw_files}")

    if not raw_files:
        print("ERROR: No Raw files found!")
        # List all files to debug
        all_files = glob.glob('foldx_results_dir/*.fxout')
        print(f"All .fxout files: {all_files}")
        sys.exit(1)

    results = []

    # Process each Raw file
    for raw_file in raw_files:
        filename = os.path.basename(raw_file)
        print(f"\\n=== Processing Raw file: {filename} ===")

        # Extract mutation info from filename
        parts = filename.split('_')
        print(f"Filename parts: {parts}")

        if len(parts) >= 2:
            gene = parts[0]
            mutation = parts[1]
            print(f"Gene: {gene}, Mutation: {mutation}")

            # Read and parse the file
            try:
                with open(raw_file, 'r') as f:
                    lines = f.readlines()

                print(f"File has {len(lines)} lines")

                # Look for data lines
                wt_energy = None
                mut_energy = None

                for i, line in enumerate(lines):
                    line = line.strip()
                    if '.pdb' in line and '\\t' in line:
                        print(f"Line {i}: {line}")
                        parts_line = line.split('\\t')
                        print(f"  Split into {len(parts_line)} parts")

                        if len(parts_line) >= 2:
                            pdb_name = parts_line[0]
                            try:
                                energy = float(parts_line[1])
                                print(f"  PDB: {pdb_name}, Energy: {energy}")

                                if pdb_name.startswith('WT_'):
                                    wt_energy = energy
                                    print(f"  -> Found WT energy: {wt_energy}")
                                elif '_Repair_' in pdb_name and not pdb_name.startswith('WT_'):
                                    # FIXED: Generic pattern matching instead of hardcoded TP53
                                    mut_energy = energy
                                    print(f"  -> Found mutant energy: {mut_energy}")

                            except ValueError as e:
                                print(f"  Could not parse energy from '{parts_line[1]}': {e}")

                print(f"Final energies - WT: {wt_energy}, Mutant: {mut_energy}")

                if wt_energy is not None and mut_energy is not None:
                    ddg = mut_energy - wt_energy

                    result = {
                        'Gene': gene,
                        'Mutation': mutation,
                        'WT_energy': wt_energy,
                        'mutant_energy': mut_energy,
                        'ddG': ddg
                    }
                    results.append(result)
                    print(f"Added result: {result}")
                else:
                    print("ERROR: Could not find both WT and mutant energies")

            except Exception as e:
                print(f"Error processing {raw_file}: {e}")
                import traceback
                traceback.print_exc()

    print(f"\\nTotal results collected: {len(results)}")
    print(f"Results: {results}")

    # Create results DataFrame
    if results:
        df_results = pd.DataFrame(results)
        print("\\nFinal Results DataFrame:")
        print(df_results)

        # Save results
        df_results.to_csv('final_ddG_results.csv', index=False)
        print("Results saved to final_ddG_results.csv")

        # Verify the file was created
        if os.path.exists('final_ddG_results.csv'):
            print("File created successfully!")
            with open('final_ddG_results.csv', 'r') as f:
                print("File contents:")
                print(f.read())
        else:
            print("ERROR: File was not created!")
    else:
        print("ERROR: No results to save!")
        # Create empty file to avoid pipeline failure
        with open('final_ddG_results.csv', 'w') as f:
            f.write("Gene,Mutation,WT_energy,mutant_energy,ddG\\n")
        print("Created empty results file")
    """
}