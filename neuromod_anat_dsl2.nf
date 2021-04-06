#!/usr/bin/env nextflow

/*
WIP DSL2 workflow for Neuromod anat processing.

Dependencies: 
    These dependencies must be installed if Docker is not going
    to be used. 
        - Advanced notmarization tools (ANTs, https://github.com/ANTsX/ANTs)
        - FSL  
        - qMRLab (https://qmrlab.org) 
        - git     

Docker: 
        - https://hub.docker.com/u/qmrlab
        - qmrlab/minimal:v2.5.0b
        - qmrlab/antsfsl:latest

Author:
    Agah Karakuzu 2019
    agahkarakuzu@gmail.com 

Users: Please see USAGE for further details
 */


/*Set defaults for parameters determining logic flow to false*/
nextflow.enable.dsl=2
include { getSubSesEntity; checkSesFolders } from './modules/bids_patterns'
include { mtsat_align_inputs } from './modules/ants'
include { extract_brain } from './modules/fsl'

params.bids = false 
params.help = false

/* Call to the mt_sat_wrapper.m will be invoked by params.runcmd.
Depending on the params.platform selection, params.runcmd 
may point to MATLAB or Octave. 
*/
if (params.platform == "octave"){

    if (params.octave_path){
        log.info "Using Octave executable declared in nextflow.config."
        params.octave = params.octave_path + " --no-gui --eval"
    }else{
        log.info "Using Octave in Docker or (if local) from the sys path."
        params.octave = "octave --no-gui --eval"
    }

    params.runcmd = params.octave 
}

if (params.platform == "matlab"){
   
    if (params.matlab_path){
        log.info "Using MATLAB executable declared in nextflow.config."
        params.matlab = params.matlab_path + " -nodisplay -nosplash -nodesktop -r"
    }else{
        log.info "Using MATLAB from the sys path."
        params.matlab = "matlab -nodisplay -nosplash -nodesktop -r"
    }

    params.runcmd = params.matlab
}

params.wrapper_repo = "https://github.com/qMRLab/qMRWrappers.git"
              
workflow.onComplete {
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    log.info "Execution duration: $workflow.duration"
}

/*Define bindings for --help*/
if(params.help) {
    usage = file("$baseDir/USAGE")

    cpu_count = Runtime.runtime.availableProcessors()
    bindings = ["ants_dim":"$params.ants_dim",
                "ants_metric":"$params.ants_metric",
                "ants_metric_weight":"$params.ants_metric_weight",
                "ants_metric_bins":"$params.ants_metric_bins",
                "ants_metric_sampling":"$params.ants_metric_sampling",
                "ants_metric_samplingprct":"$params.ants_metric_samplingprct",
                "ants_transform":"$params.ants_transform",
                "ants_convergence":"$params.ants_convergence",
                "ants_shrink":"$params.ants_shrink",
                "ants_smoothing":"$params.ants_smoothing",
                "use_b1cor":"$params.use_b1cor",
                "b1cor_factor":"$params.b1cor_factor",
                "use_bet":"$params.use_bet",
                "bet_recursive":"$params.bet_recursive",
                "bet_threshold":"$params.bet_threshold",
                "platform":"$params.platform",
                "matlab_path":"$params.matlab_path",
                "octave_path":"$params.octave_path",
                "qmrlab_path":"$params.qmrlab_path"
                ]

    engine = new groovy.text.SimpleTemplateEngine()
    template = engine.createTemplate(usage.text).make(bindings)

    print template.toString()
    return
}

entity = checkSesFolders()

if(params.bids){
    log.info "Input: $params.bids"
    bids = file(params.bids)
    derivativesDir = "$params.qmrlab_derivatives"
    log.info "Derivatives: $params.qmrlab_derivatives"

    Channel
        .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_acq-{MToff,MTon,T1w}_MTS.nii.gz", maxDepth: 3, size: 3, flat: true)
        .multiMap {sid, MToff, MTon, T1w ->
        PDw: tuple(sid, MToff)
        MTw: tuple(sid, MTon)
        T1w: tuple(sid, T1w)
        }
        .set {niiMTS}
    
    Channel
        .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_acq-{MToff,MTon,T1w}_MTS.json", maxDepth: 3, size: 3, flat: true)
        .multiMap {sid, MToff, MTon, T1w ->
        PDw: tuple(sid, MToff)
        MTw: tuple(sid, MTon)
        T1w: tuple(sid, T1w)
        }
        .set {jsonMTS}

    /* ==== BIDS: B1 map ==== */             
    /* Look for B1map in fmap folder */
    //b1_data = Channel
    //       .fromFilePairs("$bids/${dirInputLevel}fmap/sub-*_acq-flipangle_{B1plusmap}.nii.gz", maxDepth:2, size:1, flat:true)   
    // (b1raw) = b1_data       
       //    .map{sid, B1plusmap -> [tuple(sid, B1plusmap)]}     
       //    .separate(1)  
}   
else{
    error "ERROR: Argument (--bids) must be passed. See USAGE."
}

// First, join nii & json pairs with explicit notations 
// provided by the multimap
niiMTS.PDw
   .join(jsonMTS.PDw)
   .set {pairPDw}

PDw = pairPDw
        .multiMap { it -> Orig: it }

niiMTS.MTw
   .join(jsonMTS.MTw)
   .set {pairMTw}

MTw = pairMTw
        .multiMap { it -> Orig: it }

niiMTS.T1w
   .join(jsonMTS.T1w)
   .set {pairT1w}

T1w = pairT1w
        .multiMap { it -> Orig: Bet: Post: it }

// ================================== IMPORTANT 
// TUPLE ORDER: PDW --> MTW --> T1W
// NII --> JSON 
// CRITICAL TO FOLLOW THE SAME ORDER IN INPUTS

PDw.Orig
    .join(MTw.Orig)
    .join(T1w.Orig)
    .set{mtsat_for_alignment}

process publish_outputs {

    exec:
        out = getSubSesEntity("${sid}")

    input:
      tuple val(sid), \
      path(mtw_aligned), path(pdw_aligned), \
      path(mtw_disp), path(pdw_disp)

    publishDir "${derivativesDir}/${out.sub}/${out.ses}anat", mode: 'move', overwrite: true

    output:
      tuple val(sid), path(mtw_aligned), path(pdw_aligned),\
      path(mtw_disp), path(pdw_disp)

    script:
        """
        mkdir -p ${derivativesDir}
        echo "Transferring ${mtw_aligned} to ${derivativesDir}/${out.sub}/${out.ses}anat folder..."
        """
}


workflow {

mtsat_align_inputs(mtsat_for_alignment)
extract_brain(T1w.Bet)

if (!params.use_bet){
    Channel
        .empty()
        .set{mask_from_bet}
}

publish_outputs(mtsat_align_inputs.out.mtsat_from_alignment)

}

































/*
process Align_Input_Volumes {
    tag "${sid}"

    exec:
        out = getSubSesEntity("${sid}")


    input:
        tuple val(sid), file(pdw), file(mtw), file(t1w), file(pdwj), file(mtwj), file(t1wj) from agah
    
    publishDir "${derivativesDir}/${out.sub}/${out.ses}anat", mode: 'copy'
    publishDir "${derivativesDir}", pattern: '*_description.json', mode: 'copy'

    output:
        file "${sid}_T1map.nii.gz" // Really impoartant to fetch these for process to fail otherwise. 
        file "${sid}_MTsat.nii.gz"
        file "${sid}_T1map.json"
        file "${sid}_MTsat.json"
        file "*" // To capture dataset description's pattern matching publishDir and other outputs
        
    script:
        """
        echo $pdwj
        mkdir -p ${derivativesDir}
        """
}
*/