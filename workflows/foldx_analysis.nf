include { GENERATE_MUTATION_FILES } from '../modules/generate_mutation_files'
include { REPAIR_STRUCTURES_CONDITIONAL } from '../modules/repair_structures_conditional'
include { RUN_BUILDMODEL } from '../modules/run_buildmodel'
include { CALCULATE_DDG } from '../modules/calculate_ddg'
include { WRITE_MISSING_GENES } from '../modules/write_missing_genes'

workflow FOLDX_ANALYSIS {
    main:
        // Input validation
        if (!params.mutation_csv) error "Please provide --mutation_csv"
        if (!params.foldx_path) error "Please provide --foldx_path"

        // Create input channels
        mutation_csv_ch = Channel.fromPath(params.mutation_csv, checkIfExists: true)
        pdb_files_ch = Channel.fromPath("${params.structure_dir}/*.pdb", checkIfExists: false)
        parse_script_ch = Channel.fromPath("${projectDir}/bin/parse_mutations.py", checkIfExists: true)

        // Step 1: Generate mutation files
        GENERATE_MUTATION_FILES(
            mutation_csv_ch,
            params.chain,
            parse_script_ch
        )

        // Step 2: Get unique genes for repair (OPTIMIZATION: only repair each gene once)
        unique_genes_ch = GENERATE_MUTATION_FILES.out.genes
            .splitText()
            .map { it.trim() }
            .filter { it }
            .unique()
            .collectFile(name: 'unique_genes.txt', newLine: true)

        // Step 3: Repair structures (only once per unique gene)
        REPAIR_STRUCTURES_CONDITIONAL(
            unique_genes_ch,
            params.foldx_path,
            pdb_files_ch.collect(),
            params.repaired_structures_dir ?: ""
        )

        // Step 4: Prepare mutation-structure pairs
        mutation_files = GENERATE_MUTATION_FILES.out.mutation_files
            .flatten()
            .map { file ->
                def basename = file.name.replaceAll('^individual_list_', '').replaceAll('\\.txt$', '')
                def parts = basename.split('_')
                def gene = parts[0]
                def mutation = parts[1..-1].join('_')
                [gene, mutation, file]
            }

        repaired_files = REPAIR_STRUCTURES_CONDITIONAL.out.repaired_pdbs
            .flatten()
            .filter { file -> file.size() > 0 }  // Filter out empty files
            .map { file ->
                def gene = file.name.replaceAll('_Repair\\.pdb$', '')
                [gene, file]
            }

        // Combine mutation files with repaired structures - only keep valid pairs
        mutation_repair_pairs = mutation_files
            .combine(repaired_files, by: 0)
            .map { gene, mutation, mut_file, repair_file ->
                [gene, mutation, mut_file, repair_file]
            }

        // Log missing structures and collect them - FIXED VERSION
        missing_structures = mutation_files
            .map { gene, _mutation, _file -> gene }
            .unique()
            .join(repaired_files.map { gene, _file -> gene }.unique(), remainder: true)
            .filter { _gene, repair_gene -> repair_gene == null }
            .map { gene, _repair_gene -> gene }
            .view { gene -> "WARNING: No structure file found for gene: ${gene} - skipping all mutations for this gene" }

        // Step 5: Run BuildModel (only on valid pairs)
        RUN_BUILDMODEL(
            mutation_repair_pairs,
            params.foldx_path,
            params.number_of_runs
        )

        // Step 6: Calculate ΔΔG
        foldx_results = RUN_BUILDMODEL.out.foldx_results
            .map { _gene, _mutation, files -> files }
            .flatten()
            .collect()

        parse_fxout_script = Channel.fromPath("${projectDir}/bin/parse_fxout.py", checkIfExists: true)

        CALCULATE_DDG(
            foldx_results,
            parse_fxout_script
        )

        // Step 7: Write missing genes to file
        WRITE_MISSING_GENES(
            missing_structures.collect()
        )

    emit:
        final_results = CALCULATE_DDG.out.final_results
        missing_genes_file = WRITE_MISSING_GENES.out.missing_genes_file
}