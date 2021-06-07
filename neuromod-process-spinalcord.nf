#!/usr/bin/env nextflow

/* 
Header commment goes here.

TO DISPLAY HELP:
----------------
nextflow -C neuromod-process-spinalcord.config run neuromod-process-spinalcord.nf --help

SIMPLEST USE:
-------------
nextflow -C neuromod-process-spinalcord.config run neuromod-process-spinalcord.nf --bids ~/neuromod_bids_dir
*/

// Enable NEXTFLOW DSL2 to be able to include modules.
nextflow.enable.dsl=2

// Include bids_patterns module to infer session-level file 
// organization. This determines the depth of directories 
// to fetch input file pairs.
include { getSubSesEntity; checkSesFolders } from './modules/bids_patterns'

// Default behaviour if user passes 
// --bids or --help during workflow call, will be overridden.
params.bids = false 
params.help = false

// Print some fancy ASCII art.
log.info  "███    ██ ███████ ██    ██ ██████   ██████  ███    ███  ██████  ██████        ███████  ██████ ████████ "
log.info  "████   ██ ██      ██    ██ ██   ██ ██    ██ ████  ████ ██    ██ ██   ██       ██      ██         ██    "
log.info  "██ ██  ██ █████   ██    ██ ██████  ██    ██ ██ ████ ██ ██    ██ ██   ██ █████ ███████ ██         ██    "
log.info  "██  ██ ██ ██      ██    ██ ██   ██ ██    ██ ██  ██  ██ ██    ██ ██   ██            ██ ██         ██    "
log.info  "██   ████ ███████  ██████  ██   ██  ██████  ██      ██  ██████  ██████        ███████  ██████    ██    "

// This log block is executed when the workflow is completed without errors
workflow.onComplete {
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    log.info "Execution duration: $workflow.duration"
    log.info "Mnemonic ID: $workflow.runName"
}

/*Define what is shown when --help is called*/
if(params.help) {
    // To print USAGE-SCT file
    usage = file("$baseDir/USAGE-SCT")

    // To print parameter-values
    cpu_count = Runtime.runtime.availableProcessors()
    bindings = ["sct_parameter":"$params.sct_parameter",
                "sct_another_parameter":"$params.sct_another_parameter"
                ]

    engine = new groovy.text.SimpleTemplateEngine()
    template = engine.createTemplate(usage.text).make(bindings)

    print template.toString()
    return
}

// Infer entity-level file organization.
// "$bids/${entity.dirInputLevel}" will inform nextflow to look for 
// inputs in the correct directory.
entity = checkSesFolders()

// Fetch input channels only when the BIDS directory is provided. Terminate otherwise. 
if(params.bids){
    log.info "Input: $params.bids"
    bids = file(params.bids)
    // DEFINE DERIVATIVES DIRECTORY
    derivativesDir = "$params.bids/derivatives/SCT"
    log.info "Derivatives: $derivativesDir"
    log.info "Nextflow Work Dir: $workflow.workDir"

    // As channels define which files will be symbolically linked to the work directory, we need to 
    // explicitly define what we need. For example, we cannot emit a channel for nii.gz files, then 
    // expect a process to find .json by doing some string manipulation. That's why we'll use the 
    // same pattern once again for json files.

    // Initialize a channel for input file pairs of MTsat spinal cord data.
    // "$bids/${entity.dirInputLevel}sub-*_acq-{MToff,MTon,T1w}_bp-spinalcord_MTS.nii.gz" describes that 
    // file pairs of MToff, MTon and T1w will be fetched for the glob pattern that allows multiple subjects 
    // and sessions. This way, we will have all the MTsat related BIDS(nii) inputs fetched, across subjects and 
    // sessions.
    Channel
        // maxDepth is 3 anat/sub/ses size is 3, because we have 3 inputs for MTsat. 
        // The fromFilePairs requires the flat:true option to have the file pairs as separate elements 
        // in the produced tuples.
        .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_acq-{MToff,MTon,T1w}_bp-cspine_MTS.nii.gz", maxDepth: 3, size: 3, flat: true)
        // 1) sid is the subject ID, i.e. whatever grabbed by * above (e.g. sub-01_ses-003)
        // 2) .multiMap allows us to forward the items emitted by a source channel to two or 
        // more output channels mapping each input value as a separate element.
        .multiMap {sid, MToff, MTon, T1w ->
        PDw: tuple(sid, MToff)
        MTw: tuple(sid, MTon)
        T1w: tuple(sid, T1w)
        }
        // This is how we set the channel's name! 
        .set {niiMTS}
       // Now, this is what we expect to find under niiMTS: 
       // - niiMTS.PDw              [[sub-01_ses001, sub-01_ses-001_acq-PDw_bp-spinalcord_MTS.nii.gz],
       //                            [sub-01_ses002, sub-01_ses-002_acq-PDw_bp-spinalcord_MTS.nii.gz]...]
       // - niiMTS.T1w              [[sub-01_ses001, sub-01_ses-001_acq-T1w_bp-spinalcord_MTS.nii.gz],
       //                            [sub-01_ses002, sub-01_ses-002_acq-T1w_bp-spinalcord_MTS.nii.gz]...]
       // Similar for MTw.
    
    // This will do the same thing for spinal cord MTS iput pairs to fetch json files under 3 
    // channels that lives under jsonMTS namespace. Again, each channel contains tuples of [[sid, filename],...].
    Channel
        .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_acq-{MToff,MTon,T1w}_bp-cspine_MTS.json", maxDepth: 3, size: 3, flat: true)
        .multiMap {sid, MToff, MTon, T1w ->
        PDw: tuple(sid, MToff)
        MTw: tuple(sid, MTon)
        T1w: tuple(sid, T1w)
        }
        .set {jsonMTS}
    
    // Create a channel for spinal cord T1w inputs 
    Channel
      .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_bp-cspine_T1w.nii.gz", maxDepth: 3, size: 1, flat: true)
      .multiMap { it -> Nii: it }
      .set {T1w}
    
    // Create a channel for spinal cord T2w inputs 
    Channel
      .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_bp-cspine_T2w.nii.gz", maxDepth: 3, size: 1, flat: true)
      .multiMap { it -> Nii: it }
      .set {T2w}
    

    // Fetch subject ID
    Channel
      .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_bp-cspine_T2w.nii.gz", maxDepth: 3, size: 1, flat: true)
      .set {SubjectID}

}   
else{
    error "ERROR: Argument (--bids) must be passed. See USAGE-SCT."
}

/** 
>>>> What is the function of the .join operation?

The join operator creates a channel that joins together the items emitted by two channels for which 
exits a matching key. In our case, matching key is sid.

Given the following channels:
  Ch-nii  [sub-01_ses-001,sub-01_ses-001_acq-MToff_bp-spinalcord_MTS.nii.gz]
  Ch-json [sub-01_ses-001,sub-01_ses-001_acq-MToff_bp-spinalcord_MTS.json]

and the following expression: 
  Ch-nii
    .join(Ch-json)
    .set{pairExample}

The new pairExample channel will look like: 
  [sub-01_ses-001, sub-01_ses-001_acq-MToff_bp-spinalcord_MTS.nii.gz, sub-01_ses-001_acq-MToff_bp-spinalcord_MTS.json]

>>>> IMPORTANT <<<<<< 

The order at which you join channels is highly critical. In this example we joined Ch-json into
Ch-nii. Therefore the order will be [sid, nii, json] for indexes [0,1,2]. Let's say we will send this 
pairExample channel to a process as an input: 

myProcess(pairExample)

In pairExample, the input should be: 

input:
  tuple(sid), file(nii), file(json)

So that $nii and $json represent a nii and json file, respectively. Swapping the order of 
file(nii) and file(json) would result in $nii variable representing json files and vice versa.
**/

// Create a channel with name pairPDw that contains [sid, nii, json] tuples 
// for all the *_acq-MToff_ files found in the dataset.
niiMTS.PDw
   .join(jsonMTS.PDw)
   .set {pairPDw}

// Re-organize pairPDW so that we can access NIfTI files via PDw.Nii and json 
// files via PDw.Json. This reduces the chance of messing up the tuple order.
PDw = pairPDw
        .multiMap { it -> 
                    Nii: tuple(it[0],it[1])
                    Json: tuple(it[0],it[2])
                  }
// Follow the same semantic channel organization for the remaining MTsat file pairs. 
niiMTS.MTw
   .join(jsonMTS.MTw)
   .set {pairMTw}

MTw = pairMTw
        .multiMap { it -> 
                    Nii: tuple(it[0],it[1]) 
                    Json: tuple(it[0],it[2])
                    }

niiMTS.T1w
   .join(jsonMTS.T1w)
   .set {pairT1w}

T1w = pairT1w
        .multiMap { it -> 
                    Nii:  tuple(it[0],it[1]) 
                    Json: tuple(it[0],it[2])
                    }

// At this point we have PDW, MTw and T1w (each containing Nii and Json sub-channels)
// for all the spinal-cord data. Now we can combine them as required by the process we 
// will subject them to.

/** >> EXAMPLE 
Let's say we have a process named alignInputs that needs nifti files only. 
**/

// This is how we collect inputs for the alignInputs process: 
PDw.Nii
    .join(MTw.Nii)
    .join(T1w.Nii)
    // ..._for_... convention indicates that this channel is intended as an input to a process. 
    .set{mtsat_for_alignment}

/** 
Now mtsat_for_alignment is a tuple that looks like: 
  [[sub-01_ses-001, sub-01_ses-001_acq-MToff..nii.gz, sub-01_ses-001_acq-MTon..nii.gz, sub-01_ses-001_acq-T1w..nii.gz]]

This is the reason why input declaration of alignInputs process MUST respect the following order:

input:
    tuple(sid), file(PDw), file(MTw), file(T1w)


*/
/* >>>>>>> DEFINE PROCESS FOR PUBLISHING OUTPUTS <<<<<<<<<

/*  Process publishOutputs is a typical pattern in DSL2 to put final 
outputs where they belong to (by copying/moving them from the work folder).
In BIDS case, it is a derivatives folder `derivatives/sub-01/ses-001/anat/...`. 

We define this process in the body of the main workflow file as it has to 
access certain variables declared during runtime.

TODO:
    Test if { sid } instead of "${sid}" can help process access variable when 
    it is declared to the scope. Same for derivativesDir If so, make publishOutputs a module.

*/

process publishOutputs {

    // Infer session-level file organization.
    exec:
        out = getSubSesEntity("${sid}")

    // Again, order matters.
    // "val" is a Nextflow convention to declare a variable to include in the process
    // The input variables are outputs in the process. Eg: "segGM" is listed spinalcordsegmentation.process.output. Again, order matters.
    input:
      tuple val(sid), \
      file(T2w)

    // This is where the files will be dropped. Mode move indicates that 
    // the files will be moved (alternatives are copying or symlinking)
    // We set overwrite true, if there are files sharing the same name with the 
    // outputs, they'll be overwritten.
    publishDir "${derivativesDir}/${out.sub}/${out.ses}anat", mode: 'copy', overwrite: true

    // Output mirrors input as we are simply moving files.
    output:
      tuple val(sid), \
      file(T2w)

    // Generate derivatives folder
    script:
        """
        mkdir -p ${derivativesDir}
        """
}

/* >>>>>>> INCLUDE MODULES <<<<<<<<<

The reason we include modules here is that the sid variable is declared at this point. 
If we do that at the very beginning, processes won't be able to access that important 
variable.
*/

// Include T2_Segment_SpinalCord process from spinalcord_segmentation module.
include { SpinalCord } from './modules/spinalcord' addParams(qcDir: params.qcDir)
// include { T2_Segment_SpinalCord } from './modules/spinalcord_segmentation' addParams(qcDir: params.qcDir)
// include { T1_Segment_SpinalCord } from './modules/spinalcord_segmentation' addParams(qcDir: params.qcDir)
// include { T1_Vertebral_Labeling } from './modules/spinalcord_vertebral_labeling' addParams(qcDir: params.qcDir)

// >>>>>>>>>>>>>>>>> WORKFLOW DESCRIPTION START <<<<<<<<<<<<<<<<<<
workflow {

// Send files collected by mtsat_for_alignment to the 
// relevant process. 
// MTS_Align_SpinalCord(mtsat_for_alignment)

SpinalCord(SubjectID)

to_publish = SpinalCord.out.publish_spinalcord
// Collect outputs emitted by publish_spinal_mtsat channel. 
// CONVENTION: process_name.out.emit_channel_name
// mtsat_from_alignment = MTS_Align_SpinalCord.out.publish_spinal_mtsat

// Same for segmenting T2w 
// T2_Segment_SpinalCord(T2w.Nii)
// to_be_published = T2_Segment_SpinalCord.out.publish_spinal_seg
// segmentation_on_t2 = T2_Segment_SpinalCord.out.publish_spinal_seg
// 
// T1_Segment_SpinalCord(T1w.Nii)
// segmentation_on_t1 = T1_Segment_SpinalCord.out.publish_spinal_seg
// T1w.Nii
//   .join(segmentation_on_t1)
//   .set{inputs_for_vertebral_labeling}
// 
// T1_Vertebral_Labeling(inputs_for_vertebral_labeling)
// vertebral_labeling = T1_Vertebral_Labeling.out.publish_spinal_seg
// 
// segmentation_on_t2
//   .join(segmentation_on_t1)
//   .join(vertebral_labeling)
//   .set{to_be_published}

// Join channels
// mtsat_from_alignment 
//     .join(masks_from_segmentation)
//     .set {publish}

// Move files from work directory to where we'd like to find them (derivatives).
publishOutputs(to_publish)
}
