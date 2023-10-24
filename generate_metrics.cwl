cwlVersion: v1.2
class: Workflow

label: Create files for metrics_analysis

requirements:
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  input_files:
    label: Input files
    type: File[]
    doc: SAM, BAM, or CRAM format alignment files
    format:
      - edam:format_2573  # SAM
      - edam:format_2572  # BAM
      - edam:format_3462  # CRAM
    
  baits:
    label: Bait Interval list
    type: File?
    doc: An interval list file that contains the locations of the baits used in the capture.

  targets:
    label: Target Interval list
    type: File?
    doc: |
      An interval list file that contains the locations of the targets. This 
      corresponds to where the baits were designed to generate coverage. If 
      this file is not available, use the same file as used for bait intervals.

  reference:
    label: Reference genome
    type: File?
    secondaryFiles:
      - ^.dict?
      - .fai
    doc: |
      (Optional) The reference genome used to generate the aligned file and 
      interval lists. Without this file, the AT and GC dropout metrics cannot 
      be generated.
  
  output_basename:
    label: Basename for output files
    type: string
    doc: Output files will be named {output_basename}.{stat_type}.[txt|json]

  additional_metrics:
    label: Additional metrics
    type: Directory[]
    doc: |
      Additional files generated via external processes that should be added
      to the final multiqc report.

outputs:
  
  output_data:
    type: Directory
    outputSource: gather_files/pool_directory
  multiqc_report:
    type: File
    outputSource: multiqc/multiqc_html
  multiqc_data:
    type: File 
    outputSource: multiqc/multiqc_zip 

steps:
  samstats:
    run: samtools/samtools_stats.cwl
    scatter: input_file
    in:
      input_file: input_files
      ref_seq: reference
      output_basename: 
        valueFrom: $(inputs.input_file.nameroot)
    out:
      - sam_stats

  hsmetrics:
    run: picard/hsmetrics.cwl
    scatter: alignments
    in:
      alignments: input_files
      baits: baits
      targets: targets
      reference: reference
    when: $(inputs.baits != undefined && inputs.targets != undefined)
    out:
      - log
      - metrics

  gather_files:
    run: gather_files.cwl
    in:
      file_array: 
        source: [samstats/sam_stats, hsmetrics/metrics]
        linkMerge: merge_flattened
        pickValue: all_non_null
      directory_array: additional_metrics
      outdir_name: 
        valueFrom: "all_metrics"
    out:
      - pool_directory

  multiqc:
    run: multiqc/multiqc.cwl
    in:
      input_dir: gather_files/pool_directory
      report_name: output_basename
      dir_depth: 
        valueFrom: $(parseInt(3))
    out:
      - multiqc_zip
      - multiqc_html

$namespaces:
  edam: http://edamontology.org/
$schemas:
  - http://edamontology.org/EDAM_1.25.owl

