#!/usr/bin/env nextflow
params.reads = "/hpc-home/alikhan/test_reads"
Channel.fromFilePairs( params.reads + '/*_{1,2}.fastq.gz' ).into { reads_shov ; read_files_fastp  }
params.roary = false
params.quast = false

process shovill {
    cpus 8

    input:
    set val(name), file(reads) from reads_shov
    
    output:
    file "${name}.contigs.fa" into shovill_results, mlst_input, sistr_input, quast_single, quast_input

    script:
    """
    shovill --outdir $name --R1 ${reads[0]} --R2 ${reads[1]} --cpus ${task.cpus} --ram ${task.cpus * 4} --tmpdir /qib/scratch/users/alikhan/shovill_tmp 
    cp ${name}/contigs.fa ${name}.contigs.fa
    """

}

process prokka {
    cpus 8
    input:
    file(contig) from shovill_results
    publishDir 'prokka', mode: 'copy', overwrite: true
    
    output:
    file "${contig.simpleName}/*" into prokka_results 
    file "*.gff" into gff_roary

    script:
    """
    prokka ${contig}  --outdir  ${contig.simpleName} --cpus ${task.cpus} --prefix ${contig.simpleName} --locustag P --increment 10 --gffver 3 --mincontig 200 --kingdom Bacteria --gcode 11 --evalue 1e-06
    cp ${contig.simpleName}/*.gff ${contig.simpleName}.gff 
    """

} 

process mlst {
    input:
    file(contig) from mlst_input
    publishDir 'mlst', mode: 'copy', overwrite: true
    
    output:
    file "${contig.simpleName}.tsv" into mlst_results 

    script:
    """
    mlst ${contig} > ${contig.simpleName}.tsv
    """

}

process sistr {
    input:
    file(contig) from sistr_input
    publishDir 'sistr', mode: 'copy', overwrite: true

    output:
    file "${contig.simpleName}.tab" into sistr_results

    script:
    """ 
    sistr ${contig} -f tab -o ${contig.simpleName} --tmp-dir /qib/scratch/users/alikhan/sistr
    """


}

process quast {
    publishDir "quast/", mode: 'copy', overwrite: true

    input:
    file(quast) from quast_input.collect()
    
    when:
    params.quast

    output:
    file "quast_report/*" into quast_all_results

    script:
    """
    quast.py ${quast} -o quast_report 
    """

}

process quastsingle {
    input:
    file(contig) from quast_single
    publishDir 'quastsingle', mode: 'copy', overwrite: true

    when: 
    params.quast == false

    output:
    file "${contig.simpleName}/" into quastsingle_all_results

    script:
    """
    quast ${contig} -o ${contig.simpleName}
    """


}

process fastp {
    input:
    set val(name), file(reads) from read_files_fastp
    publishDir "fastp/", mode: 'copy', overwrite: true

    output:
    file "*.fastp.json" into fastp_results
    
    script:
    """
    fastp -i ${reads[0]} -I ${reads[1]}  --json ${name}.fastp.json
    """
}


process roary {
    cpus 20
    time '47h' 
    queue 'qib-long,qib-medium,qib-short,nbi-medium,nbi-short,nbi-long'
    publishDir 'roary', mode: 'copy', overwrite: true

    when:
    params.roary
 
    input:
    file(genome) from gff_roary.collect()

    output:
    file "roary_out/*" into roary_all_results

    script:
    """
    roary -p ${task.cpus} -ne -f roary_out ${genome}
    """
}
