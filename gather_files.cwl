cwlVersion: v1.2
class: ExpressionTool
label: Gathers files and directories into a single output Directory

doc: From https://www.biostars.org/p/365679/

requirements:
  InlineJavascriptRequirement: {}

inputs:
  file_single:
    type: File?
    label: A single file to add to the output directory.
  file_array:
    type: File[]?
    label: An array of files to add to the output directory.
  directory_single:
    type: Directory?
    label: A single input directory to add to the output directory as a subdirectory.
  directory_array:
    type: Directory[]?
    label: An array of directories to add to the output directory as subdirectories.
  outdir_name:
    type: string
    label: Name of the output directory.

outputs:
  pool_directory:
    type: Directory
    label: Directory with all input files/folders. 

expression: |
  ${
    //Check which input files/directories are present. Add them to the new directory.
    var outputList = [];
    if ( inputs.file_single != undefined ) {
      outputList.push( inputs.file_single );
    }
    if ( inputs.directory_single != undefined ) {
      outputList.push( inputs.directory_single );
    }
    if ( inputs.file_array != undefined ) {
      for ( var count = 0; count < inputs.file_array.length; count++ ) {
        var nextfile = inputs.file_array[count];
        outputList.push( nextfile );
      }
    }
    if ( inputs.directory_array != undefined ) {
      for ( var count = 0; count < inputs.directory_array.length; count++ ) {
        var nextdir = inputs.directory_array[count];
        outputList.push( nextdir );
      }
    }
    return {
      "pool_directory": {
        "class": "Directory",
        "basename": inputs.outdir_name,
        "listing": outputList
      }
    };
  }