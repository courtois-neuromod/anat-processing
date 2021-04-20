#!/usr/bin/env nextflow

/*
This workflow contains pre- and post-processing steps to 
calculate metrics in the spinal cord.

Dependencies: 
    These dependencies must be installed if Docker is not going
    to be used. 
        - SCT
        - git     

Author:
    Agah Karakuzu, Julien Cohen-Adad 2021
    jcohen@polymtl.ca

Users: Please see USAGE for further details
// TODO: where is "USAGE"?
// TODO: add usage for testing pipeline in one subject
*/

/*Set defaults for parameters determining logic flow to false*/
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

/*Scrape file names from a BIDS-compatible dataset
Note:
    BIDS for qMRI is currently under development (BEP001,https://github.com/bids-standard/bep001)
    The current format is valid as of late 2019 and subjected to change.
    For B1plusmaps, there is not a specification yet. To circumvent this 
    issue, these (optional) maps are assumed to be located at the fmap
    folder with _B1plusmap suffix.   
*/
if(params.bids){
    log.info "Input: $params.bids"
    bids = file(params.bids)
    
    /* ==== BIDS: MTSat inputs ==== */  
    /* Here, alphabetical indexes matter. Therefore, MToff -> MTon -> T1w */
    in_data = Channel
        .fromFilePairs("$bids/**/**/anat/sub-*_acq-{MToff,MTon,T1w}_MTS.nii.gz", maxDepth: 3, size: 3, flat: true)
    (pdw, mtw, t1w) = in_data
        .map{sid, MToff, MTon, T1w  -> [    tuple(sid, MToff),
                                            tuple(sid, MTon),
                                            tuple(sid, T1w)]}                                   
        .separate(3)

    in_data = Channel
        .fromFilePairs("$bids/**/**/anat/sub-*_acq-{MToff,MTon,T1w}_MTS.json", maxDepth: 3, size: 3, flat: true)
    (pdwj, mtwj, t1wj) = in_data
        .map{sid, MToff, MTon, T1w  -> [    tuple(sid, MToff),
                                            tuple(sid, MTon),
                                            tuple(sid, T1w)]}                                   
        .separate(3)    

    /* ==== BIDS: B1 map ==== */             
    /* Look for B1map in fmap folder */
    b1_data = Channel
           .fromFilePairs("$bids/**/**/fmap/sub-*_acq-flipangle_dir-AP_B1plusmap.nii.gz", maxDepth:3, size:1, flat:true)
           .set {b1raw}
    //(b1raw) = b1_data       
     //      .map{sid, B1plusmap -> [tuple(sid, B1plusmap)]}     
     //      .separate(1)
}   
else{
    error "ERROR: Argument (--bids) must be passed. See USAGE."
}

/*Each data type is defined as a channel. To pass all the channels 
  to the same process accurately, these channels must be joined. 
*/ 

/*Split T1w into three channels
    t1w_pre_ch1 --> mtsat_for_alignment
    t1w_pre_ch2 --> t1w_for_bet
    t1w_pre_ch3 --> t1w_post
*/
t1w.into{t1w_pre_ch1; t1w_for_bet; t1w_post}

/* Merge PDw, MTw and T1w for alignment*/
pdw 
    .join(mtw)
    .join(t1w_pre_ch1)
    .set{mtsat_for_alignment}

log.info "SCT: spinal cord analysis pipeline"
log.info "=================================="
log.info ""
// Artwork created with https://patorjk.com/software/taag/#p=display&f=Doom&t=Neuromod%20-%20SCT
log.info "_   _                                          _            _____ _____ _____ "
log.info "| \ | |                                        | |          /  ___/  __ \_   _|"
log.info "|  \| | ___ _   _ _ __ ___  _ __ ___   ___   __| |  ______  \ `--.| /  \/ | |"  
log.info "| . ` |/ _ \ | | | '__/ _ \| '_ ` _ \ / _ \ / _` | |______|  `--. \ |     | |"  
log.info "| |\  |  __/ |_| | | | (_) | | | | | | (_) | (_| |          /\__/ / \__/\ | |"  
log.info "\_| \_/\___|\__,_|_|  \___/|_| |_| |_|\___/ \__,_|          \____/ \____/ \_/"  
log.info ""
log.info "Start time: $workflow.start"
log.info ""
log.info ""
log.info "DATA"
log.info "===="
log.info ""
log.info "BIDS option has been enabled."
log.warn "qMRI protocols will be read from sidecar .json files for MTSAT and MTR."
log.warn "Some protocols for MP2RAGE are hardcoded."
log.info ""
log.info "OPTIONS"
log.info "======="
log.info ""
log.info "[GLOBAL]"
log.info "---------------"
log.info "Selected platform: $params.platform"
log.info "BET enabled: $params.use_bet"
log.info "B1+ correction enabled: $params.use_b1cor"
log.info ""
log.info "[ANTs Registration]"
log.info "-------------------"
log.info "Dimensionality: $params.ants_dim"
log.info "Metric: $params.ants_metric"
log.info "Weight: $params.ants_metric_weight"
log.info "Number of bins: $params.ants_metric_bins"
log.info "Sampling type: $params.ants_metric_sampling"
log.info "Sampling percentage: $params.ants_metric_samplingprct"
log.info "Transform: $params.ants_transform"
log.info "Convergence: $params.ants_convergence"
log.info "Shrink factors: $params.ants_shrink"
log.info "Smoothing sigmas: $params.ants_smoothing"
log.info ""
log.info "[FSL BET]"
log.info "---------------"
log.info "Enabled: $params.use_bet"
log.info "Fractional intensity threshold: $params.bet_threshold"
log.info "Robust brain center estimation: $params.bet_recursive"
log.info ""
log.info "[qMRLab mt_sat]"
log.info "---------------"
log.warn "Acquisition protocols will be read from  sidecar .json files (BIDS)."
if (params.use_b1cor){
log.info "B1+ correction has been ENABLED."  
log.warn "Process will be skipped for participants missing a B1map file."   
log.info "B1 correction factor: $params.b1cor_factor"}
if (!params.use_b1cor){
log.info "B1+ correction has been DISABLED."
log.warn "Process will NOT take any (possibly) existing B1maps into account."
}
log.info ""
log.info "======================="

process T2_Segment_SpinalCord {
    tag "${sid}"
    publishDir "$bids/derivatives/sct/${sid}", mode: 'copy'

    input:
        tuple val(sid), file(pdw), file(mtw), file(t1w) from mtsat_for_alignment

    output:
        tuple val(sid), "${sid}_acq-MTon_MTS_aligned.nii.gz", "${sid}_acq-MToff_MTS_aligned.nii.gz"\
        into mtsat_from_alignment
        file "${sid}_acq-MTon_MTS_aligned.nii.gz"
        file "${sid}_acq-MToff_MTS_aligned.nii.gz"

    script:
    // TODO: add QC report
        """
        sct_deepseg_sc -i ${sid}_bp-cspine_T2w.nii.gz -c t2 
        """
}

