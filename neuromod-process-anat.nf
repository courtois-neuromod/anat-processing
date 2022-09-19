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

params.bids = false 
params.help = false

log.info  "##    # ###### #    # #####   ####  #    #  ####  #####  "
log.info " # #   # #      #    # #    # #    # ##  ## #    # #    # "
log.info " #  #  # #####  #    # #    # #    # # ## # #    # #    # "
log.info " #   # # #      #    # #####  #    # #    # #    # #    # "
log.info " #    ## #      #    # #   #  #    # #    # #    # #    # "
log.info " #     # ######  ####  #    #  ####  #    #  ####  #####  "

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
    log.info "Mnemonic ID: $workflow.runName"
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
    log.info "Nextflow Work Dir: $workflow.workDir"

    Channel
        .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_flip-{1,2}_mt-{off,on}_MTS.nii.gz", maxDepth: 3, size: 3, flat: true)
        .multiMap {sid, MToff, MTon, T1w ->
        PDw: tuple(sid, MToff)
        MTw: tuple(sid, MTon)
        T1w: tuple(sid, T1w)
        }
        .set {niiMTS}
    
    Channel
        .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_flip-{1,2}_mt-{off,on}_MTS.json", maxDepth: 3, size: 3, flat: true)
        .multiMap {sid, MToff, MTon, T1w ->
        PDw: tuple(sid, MToff)
        MTw: tuple(sid, MTon)
        T1w: tuple(sid, T1w)
        }
        .set {jsonMTS}

    Channel
        .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_UNIT1.nii.gz", maxDepth: 3, size: 1, flat: true)
        .multiMap { it -> UNIT1: it }
        .set {niiMP2RAGE}

    Channel
        .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_UNIT1.json", maxDepth: 3, size: 1, flat: true)
        .multiMap { it -> UNIT1: it }
        .set {jsonMP2RAGE}


    /* ==== BIDS: B1 map ==== */             
    /* ==== BIDS: B1 map ==== */             
    /* Look for B1map in fmap folder */
    Channel
           .fromFilePairs("$bids/**/**/fmap/sub-*_acq-famp_TB1TFL.nii.gz", maxDepth:3, size:1, flat:true)
           .multiMap { it -> AngleMap: it }
           .set {B1}

    Channel
    .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_ses-*_T1w.nii.gz", maxDepth:3, size:1, flat:true)
    .multiMap { it -> Nii: it}
    .set {T1wHighRes}

    Channel
    .fromFilePairs("$bids/${entity.dirInputLevel}sub-*_inv-2_MP2RAGE.nii.gz", maxDepth: 3, size: 1, flat: true)
    .multiMap { it -> Nii: it }
    .set {inv2}
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
        .multiMap { it -> 
                    Nii: tuple(it[0],it[1])
                    Json: tuple(it[0],it[2])
                  }

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


// ================================== IMPORTANT 
// TUPLE ORDER: PDW --> MTW --> T1W
// NII --> JSON 
// CRITICAL TO FOLLOW THE SAME ORDER IN INPUTS

PDw.Nii
    .join(MTw.Nii)
    .join(T1w.Nii)
    .set{mtsat_for_alignment}

niiMP2RAGE.UNIT1
    .join(jsonMP2RAGE.UNIT1)
    .set{pairMP2RAGE}

T1wHighRes.Nii
    .join(niiMTS.T1w)
    .join(inv2.Nii)
    .set{segInputs}

process publishOutputs {

    exec:
        out = getSubSesEntity("${sid}")

    input:
      tuple val(sid), \
      path(mtw_aligned), path(pdw_aligned), \
      path(mtw_disp), path(pdw_disp), \
      path(t1map), path(mtsat), path(t1mapj), \
      path(mtsatj), path(qmrmodel), path(mp2raget1), \
      path(mp2raget1j),path(mp2rager1),path(mp2rager1j), path(mp2ragemodel), \
      path(mtrnii), path(mtrjson), path(mtrmodel)

    publishDir "${derivativesDir}/${out.sub}/${out.ses}anat", mode: 'copy', overwrite: true

    output:
      tuple val(sid), \
      path(mtw_aligned), path(pdw_aligned), \
      path(mtw_disp), path(pdw_disp), \
      path(t1map), path(mtsat), path(t1mapj), \
      path(mtsatj), path(qmrmodel), path(mp2raget1), \
      path(mp2raget1j),path(mp2rager1),path(mp2rager1j), path(mp2ragemodel), \
      path(mtrnii), path(mtrjson), path(mtrmodel)

    script:
        """
        mkdir -p ${derivativesDir}
        echo "Transferring ${mtw_aligned} to ${derivativesDir}/${out.sub}/${out.ses}anat folder..."
        """
}

process publishOutputsFmap {

    exec:
        out = getSubSesEntity("${sid}")

    input:
      tuple val(sid), \
      path(b1res), path(smooth)

    publishDir "${derivativesDir}/${out.sub}/${out.ses}fmap", mode: 'copy', overwrite: true

    output:
      tuple val(sid), \
      path(b1res),path(smooth)

    script:
        """
        mkdir -p ${derivativesDir}
        """
}

process publishOutputsMasks {

    exec:
        out = getSubSesEntity("${sid}")

    input:
      tuple val(sid), \
      path(mtsgm), path(mtswm), \
      path(mp2ragegm), path(mp2ragewm), \
      path(mts_disp), path(mp2rage_disp)

    publishDir "${derivativesDir}/${out.sub}/${out.ses}anat", mode: 'copy', overwrite: true

    output:
      tuple val(sid), \
      path(mtsgm), path(mtswm), \
      path(mp2ragegm), path(mp2ragewm), \
      path(mts_disp), path(mp2rage_disp)

    script:
        """
        mkdir -p ${derivativesDir}
        """
}

include { alignMtsatInputs; resampleB1; generateRegionMasks } from './modules/ants'
include { extractBrain } from './modules/fsl'
include { smoothB1WithMask; smoothB1WithoutMask } from './modules/filter_map' addParams(runcmd: params.runcmd)
include { fitMtsatWithB1Mask; fitMtsatWithB1; fitMtsatWithBet; fitMtsat} from './modules/mt_sat' addParams(runcmd: params.runcmd)
include { fitMp2rageUni} from './modules/mp2rage' addParams(runcmd: params.runcmd)
include { fitMtratio} from './modules/mt_ratio' addParams(runcmd: params.runcmd)


workflow {

fitMp2rageUni(pairMP2RAGE)

publish_mp2rage = fitMp2rageUni.out.mp2rage_output
// EXECUTE PROCESS (tuple order: sid, pdw, mtw, t1w)
alignMtsatInputs(mtsat_for_alignment)

// Get aligned images (tuple order: sid, pdw, mtw, pdwdisp, mtwdisp)
mtsat_from_alignment = alignMtsatInputs.out.mtsat_from_alignment

// All these files will be eventually published, but we need a subsample of them
// to proceed with the workflow, which are first 3 tuple elements (sid, pdw, mtw)
mtsat_from_alignment
        .multiMap{it ->
        Publish: it
        Fit: tuple(it[0],it[1],it[2])
        Mtr: tuple(it[0],it[1],it[2])
        }
        .set {Aligned}

// EXECUTE PROCESS (tuple order: sid, t1w)
extractBrain(T1w.Nii)

mask_from_bet = extractBrain.out.mask_from_bet

if (!params.use_bet){
    Channel
        .empty()
        .set{mask_from_bet}
}

// Clone
Mask = mask_from_bet
            //.multiMap { it -> Split1: Split2: Split3: it }

// Join channels by tuple index for resampling b1+ map (ref t1w)
T1w.Nii
    .join(B1.AngleMap)
    .set{b1_for_alignment}

// Process val(sid), file(t1w), file(b1raw)
resampleB1(b1_for_alignment)

// Collect output
b1_resampled = resampleB1.out.b1_resampled

// Join channels for smoothing with map
b1_resampled
    .join(Mask)
    .set {b1_for_smoothing_with_mask}

if (params.use_bet){

// EXECUTE PROCESS (tuple order: sid, b1, mask)
smoothB1WithMask(b1_for_smoothing_with_mask)

// Collect ouputs
b1_filtered = smoothB1WithMask.out.b1_filtered
                        .multiMap{it->
                        Publish: it
                        Nii: tuple(it[0],it[1])
                        }

}else{

// EXECUTE PROCESS (tuple order: sid, b1)
smoothB1WithoutMask(b1_resampled)

// Collect ouputs
b1_filtered = smoothB1WithoutMask.out.b1_filtered
                        .multiMap{it->
                        Publish: it
                        Nii: tuple(it[0],it[1])
                        }
}

// Join data channels based on parameter selection
// Fit with B1 
if (params.use_b1cor){

Aligned.Fit
    .join(T1w.Nii)
    .join(PDw.Json)
    .join(MTw.Json)
    .join(T1w.Json)
    .join(b1_filtered.Nii)
    .set{fitting_with_b1}

fitting_with_b1
    .join(Mask)
    .set{mtsat_with_b1_bet}

fitMtsatWithB1Mask(mtsat_with_b1_bet)

fitMtsatWithB1(fitting_with_b1)

}else{

// Fit without B1 map channel 
Aligned.Fit
    .join(T1w.Nii)
    .join(PDw.Json)
    .join(MTw.Json)
    .join(T1w.Json)
    .set{mtsat_fitting_without_b1}

mtsat_fitting_without_b1
    .join(Mask)
    .set{ fitting_without_b1_bet}

fitMtsatWithBet(fitting_without_b1_bet)

fitMtsat(mtsat_fitting_without_b1)

}

// Fit MTR
fitMtratio(Aligned.Mtr)

if (params.use_bet&params.use_b1cor){
Aligned.Publish
    .join(fitMtsatWithB1Mask.out.publish_mtsat)
    .join(publish_mp2rage)
    .join(fitMtratio.out.mtratio_output)
    .set {publish}
}
if (!params.use_bet&params.use_b1cor){
Aligned.Publish
    .join(fitMtsatWithB1.out.publish_mtsat)
    .join(publish_mp2rage)
    .join(fitMtratio.out.mtratio_output)
    .set {publish}
    }
if (params.use_bet&!params.use_b1cor){
Aligned.Publish
    .join(fitMtsatWithBet.out.publish_mtsat)
    .join(publish_mp2rage)
    .join(fitMtratio.out.mtratio_output)
    .set {publish}
}
if (!params.use_bet&!params.use_b1cor){
Aligned.Publish
    .join(fitMtsat.out.publish_mtsat)
    .join(publish_mp2rage)
    .join(fitMtratio.out.mtratio_output)
    .set {publish}
}

if (params.use_b1cor){
b1_resampled
   .join(b1_filtered.Nii)
   .set{publishfmap}
}

generateRegionMasks(segInputs)

publishOutputs(publish)
if (params.use_b1cor){
publishOutputsFmap(publishfmap)
}
publishOutputsMasks(generateRegionMasks.out.region_masks)

}
