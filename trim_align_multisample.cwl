cwlVersion: v1.2
class: Workflow

label: Trim, align, sort reads for multiple samples.
doc: | 
  Use cutadapt, bwa mem, and samtools sort to generate analysis ready aligned reads in BAM format.

requirements:
  MultipleInputFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  SubworkflowFeatureRequirement: {}
  InlineJavascriptRequirement:
    expressionLib:
     - { $include: bwa/helper_functions.js }
  StepInputExpressionRequirement: {}

inputs:
  read1array:
    label: Read1 FASTQ
    type:
      type: array
      items: File
    doc: FASTQ file containing reads to align.

  read2array: 
    label: Read2 FASTQ
    type: 
      type: array
      items: File
    doc: Read2 FASTQ file.

  ref_genome:
    label: Genome FASTA 
    type: File
    secondaryFiles: 
      - .amb
      - .ann
      - .bwt
      - .pac
      - .sa
    doc: Reference genome sequence with BWA indices present side-by-side.

  adapter3pR1:
    label: 3' Read1 adapter
    type: string
    doc: Sequence of adapter ligated to the 3' end of read1. The adapter and subsequent bases are trimmed. If '$' is appended ('anchoring'), the adapter is only found if it is a suffix of the read.
  
  adapter3pR2:
    label: 3' Read2 adapter
    type: string
    doc: Sequence of adapter ligated to the 3' end of read2. The adapter and subsequent bases are trimmed. If '$' is appended ('anchoring'), the adapter is only found if it is a suffix of the read.

  nextseq_trim:
    label: Enable quality trimming for Illumina 2-color instruments
    type: int?
    doc: Illumina 2-color instrument specific quality trimming (each read). Trims dark cycles appearing as high quality G bases from 3' end of reads. Works like standard quality trimming. Quality threshold is applied for A/C/T, but qualities of G bases are ignored.

  output_sec_align:
    label: output all alignments?
    type: boolean?
    doc: Output all alignments for SE or unpaired PE reads. These alignments will be flagged as secondary.

  append_comments:
    label: append FASTA/Q comments?
    type: boolean?
    doc: Append FASTA/Q comments to SAM output. Can be used to transfer read meta data (such as barcodes)
         to the SAM output. Note that all comments after the first space in the read header line) must 
         conform to the SAM spec. Malformed comments will lead to incorrectly formatted SAM output.
      
  threads:
    label: Num threads
    type: int?
    doc: (Optional) number of processing threads to use for each sample.

  platform:
    label: "Platform/technology used to produce the reads (PL)"
    type:
      type: enum
      symbols: [ CAPILLARY, LS454, ILLUMINA, SOLID, HELICOS, IONTORRENT, PACBIO ]  
    
outputs:
  trim_reports:
    type: 
      type: array
      items: File
    outputSource: trim_align_sample/trim_report
  read1_trimmed_fastqs:
    type:  
      type: array
      items: File
    outputSource: trim_align_sample/read1_trimmed_fastq
  read2_trimmed_fastqs:
    type:  
      type: array
      items: File
    outputSource: trim_align_sample/read2_trimmed_fastq
  sorted_bams:
    type:  
      type: array
      items: File
    secondaryFiles:
      - ^.bai
    outputSource: trim_align_sample/sorted_bam
  raw_bams:
    type:  
      type: array
      items: File
    outputSource: trim_align_sample/raw_bam
  deduped_bams:
    type: File[]
    format: edam:format_2572  # BAM
    outputSource: trim_align_sample/deduped_bam
  dedup_metrics:
    type: File[]
    outputSource: trim_align_sample/dedup_metrics

steps:
  trim_align_sample:
    run: trim_align_mdup.cwl
    scatter: [read1, read2]
    scatterMethod: dotproduct
    in:
      read1: read1array
      read2: read2array
      adapter3pR1: adapter3pR1
      adapter3pR2: adapter3pR2
      output_basename: 
        valueFrom: ${ return generate_common_name(inputs.read1.basename, inputs.read2.basename); }
      nextseq_trim: nextseq_trim
      ref_genome: ref_genome
      output_sec_align: output_sec_align
      append_comments: append_comments
      threads: threads
      read_group: 
        source: "platform"
        valueFrom: |
          ${ return read_group_values(inputs.read1.basename, inputs.read_group); }
    out:
      - trim_report
      - read1_trimmed_fastq
      - read2_trimmed_fastq
      - sorted_bam
      - raw_bam
      - deduped_bam
      - dedup_metrics
    
  
$namespaces:
  edam: http://edamontology.org/
$schemas:
  - http://edamontology.org/EDAM_1.25.owl
