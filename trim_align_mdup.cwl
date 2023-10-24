cwlVersion: v1.2
class: Workflow

label: Trim, align, sort reads.
doc: | 
  Use cutadapt, bwa mem, and samtools sort to generate analysis ready aligned reads in BAM format.

requirements:
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  SubworkflowFeatureRequirement: {}

inputs:
  read1:
    label: Read1 FASTQ
    type: File
    format: 
      - edam:format_1930 # FASTQ (no quality score encoding specified)
      - edam:format_1931 # FASTQ-Illumina
      - edam:format_1932 # FASTQ-Sanger
      - edam:format_1933 # FASTQ-Solexa
    doc: FASTQ file containing reads to align.

  read2: 
    label: Read2 FASTQ
    type: File
    format:
      - edam:format_1930 # FASTQ (no quality score encoding specified)
      - edam:format_1931 # FASTQ-Illumina
      - edam:format_1932 # FASTQ-Sanger
      - edam:format_1933 # FASTQ-Solexa
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
    label: Quality trimming for Illumina 2-color instruments
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
      
  output_basename:
    label: Output name
    type: string
    doc: Basename for output files

  threads:
    label: Num threads
    type: int?
    doc: (Optional) number of processing threads to use.
    
  read_group:
    label: Read group details
    type: 
      - type: record
        name: ReadGroupDetails
        fields:
          sample:
            type: string
            label: "Sample name (SM)"
          identifier:
            type: string
            label: "Read group identifier (ID)"
            doc: "This value must be unique among multiple samples in your experiment"
          platform:
            type:
              type: enum
              symbols: [ CAPILLARY, LS454, ILLUMINA, SOLID, HELICOS, IONTORRENT, PACBIO ]
            label: "Platform/technology used to produce the reads (PL)"
          library:
            type: string
            label: "Library name (LB)"

outputs:
  trim_report:
    type: File 
    format: edam:format_3464
    outputSource: trim/json_report
  read1_trimmed_fastq:
    type: File
    format: $(inputs.read1.format)
    outputSource: trim/read1_trimmed_fastq
  read2_trimmed_fastq:
    type: File
    format: $(inputs.read2.format)
    outputSource: trim/read2_trimmed_fastq
  sorted_bam:
    type: File
    secondaryFiles: 
      - ^.bai
    format: edam:format_2572  # BAM
    outputSource: sort/sorted_alignments
  raw_bam: 
    type: File
    format: edam:format_2572  # BAM
    outputSource: align/aligned_reads
  deduped_bam:
    type: File
    format: edam:format_2572  # BAM
    outputSource: mark_dup/deduped_alignments
  dedup_metrics:
    type: File 
    outputSource: mark_dup/metrics
  
steps:
  trim:
    run: cutadapt/cutadapt-paired.cwl
    in:
      read1: read1
      read2: read2
      adapter3pR1: adapter3pR1
      adapter3pR2: adapter3pR2
      output_basename: output_basename
      nextseq_trim: nextseq_trim
    out:
      - read1_trimmed_fastq
      - read2_trimmed_fastq
      - json_report
      - text_report
  
  align:
    run: bwa/bwamem.cwl
    in:
      read1: trim/read1_trimmed_fastq
      read2: trim/read2_trimmed_fastq
      ref_genome: ref_genome
      output_sec_align: output_sec_align
      append_comments: append_comments
      output_basename: output_basename
      read_group: read_group
      threads: threads
    out:
      - aligned_reads

  sort:
    run: samtools/sortbam.cwl
    in:
      unsorted_alignments: align/aligned_reads
      sort_mode:
        valueFrom: "coordinate"
      output_basename: 
        valueFrom: $(inputs.unsorted_alignments.nameroot)
    out:
      - sorted_alignments

  mark_dup:
    run: picard/markdups.cwl
    in:
      alignments: sort/sorted_alignments
    out:
      - deduped_alignments
      - log
      - metrics


$namespaces:
  edam: http://edamontology.org/
$schemas:
  - http://edamontology.org/EDAM_1.25.owl