#!/usr/bin/env nextflow
params.reference = "ref/LT2.fna"
params.filelist  = 'filelist.csv'
params.sra  = 'sra.txt'

raw_reads = Channel.fromPath( params.filelist ).splitCsv( header:true ).map{ row-> tuple(row.name, [file(row.r1), file(row.r2)]) }
ref = file(params.reference)
params.tree = false
params.key = '82a3529e6e6e26d0159bfdabfdb50cf68a09'

acc_number = file(params.sra).readLines().each{it}
sra_reads = Channel.fromSRA(acc_number, apiKey: params.key, max: 10)
reads_snippy = raw_reads.mix(sra_reads)

process snippy {
   cpus 20

   input:
   set name, file(reads) from reads_snippy
   file ref 

   output:
   file "${name}" into core_aln_results

   script:
   """
   snippy --cpus ${task.cpus} --ref ${ref} --R1 ${reads[0]} --R2 ${reads[1]} --outdir ${name} --cleanup
   """
}

process snippycore {
    publishDir 'snippy', mode: 'copy', overwrite: true
    cpus 10 

    input:
    file(snippy) from core_aln_results.collect()

    output:
    file "core.full.aln" into snipclean
    file "core*" into snippyout

    script:
    """
    snippy-core --mask-char=N --ref ${params.reference} ${snippy}
    """
}

process snippyclean {
    publishDir 'snippy', mode: 'copy', overwrite: true

    input: 
    file(core) from snipclean    

    output:
    file "clean.full.aln" into ( iq_align, nj_core_align, ft_core_align, clonal_align, fast_align)

    script:
    """
    snippy-clean_full_aln ${core} > clean.full.aln
    """
}


process rapidnj  {
    publishDir 'rapidnj', mode: 'copy', overwrite: true
 
    input:
    file core from nj_core_align 

    output:
    file 'rapidnj.tree' into njtree 

    script:
    """
    rapidnj -n -i fa ${core} > rapidnj.tree
    """
}

process iqtreefast{
   cpus 100
   publishDir 'iqtree_fast', mode: 'copy', overwrite: true

   when:
   params.tree

   input:
   file align from fast_align

   output:
   file 'iqtree_fast*' into iqfastout
   file 'iqtree_fast.treefile' into iqtreefastout

   script:
   """
   iqtree -s ${align} -pre iqtree_fast -nt ${task.cpus} -m GTR+G -fast
   """

}

process clonal{
   publishDir 'clonal', mode: 'copy', overwrite: true    

   when:
   params.tree

   input: 
   file tree from iqtreefastout
   file align from clonal_align
   
   output:
   file 'clonal*' into clonalout

   script:
   """
   ClonalFrameML ${tree} ${align} clonal
   """
}
