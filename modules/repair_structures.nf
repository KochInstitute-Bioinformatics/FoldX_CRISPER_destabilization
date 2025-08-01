process REPAIR_STRUCTURES {
    conda "conda-forge::python=3.9"
    
    publishDir "${params.outdir}/repaired_structures", mode: 'copy'
    
    input:
    path genes_file
    val foldx_path
    val structure_dir
    
    output:
    path "*_Repair.pdb", emit: repaired_pdbs
    
    script:
    """
    while IFS= read -r gene; do
        if [ -f "${structure_dir}/\${gene}.pdb" ] && [ ! -f "${structure_dir}/\${gene}_Repair.pdb" ]; then
            ${foldx_path} --command=RepairPDB --pdb=\${gene}.pdb --output-dir=${structure_dir}
            cp "${structure_dir}/\${gene}_Repair.pdb" .
        elif [ -f "${structure_dir}/\${gene}_Repair.pdb" ]; then
            cp "${structure_dir}/\${gene}_Repair.pdb" .
        fi
    done < ${genes_file}
    """
}