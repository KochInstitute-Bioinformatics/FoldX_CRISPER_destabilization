process RUN_BUILDMODEL {
    conda "conda-forge::python=3.9"
    
    publishDir "${params.outdir}/foldx_results", mode: 'copy'
    
    input:
    path mutation_files
    path repaired_pdbs
    val foldx_path
    val structure_dir
    
    output:
    path "*/Average.fxout", emit: foldx_results
    
    script:
    """
    for mut_file in ${mutation_files}; do
        # Extract gene and mutation info from filename
        base_name=\$(basename \$mut_file .individual_list.txt)
        gene=\$(echo \$base_name | cut -d'_' -f1)
        mutation=\$(echo \$base_name | cut -d'_' -f2-)
        
        # Determine if this is WT or mutant
        if [[ \$mutation == "WT" ]]; then
            out_dir="\${gene}_WT"
        else
            out_dir="\${gene}_\${mutation}"
        fi
        
        # Skip if already exists
        if [ -f "\${out_dir}/Average.fxout" ]; then
            continue
        fi
        
        # Create output directory and copy files
        mkdir -p \$out_dir
        cp \${gene}_Repair.pdb \$out_dir/
        cp \$mut_file \$out_dir/individual_list.txt
        
        # Run FoldX BuildModel
        cd \$out_dir
        ${foldx_path} --command=BuildModel --pdb=\${gene}_Repair.pdb --mutant-file=individual_list.txt --numberOfRuns=${params.number_of_runs}
        cd ..
    done
    """
}