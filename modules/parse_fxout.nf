process PARSE_FXOUT {
    conda "conda-forge::pandas=2.0.3"
    
    publishDir "${params.outdir}/parsed_outputs", mode: 'copy'
    
    input:
    path fxout_file
    
    output:
    path "*.csv", emit: csv
    
    script:
    def prefix = fxout_file.baseName
    """
    parse_fxout.py ${fxout_file} ${prefix}_clean.csv
    """
}