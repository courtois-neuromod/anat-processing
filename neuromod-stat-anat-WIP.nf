// THIS IS A WIP SCRIPT
// regionStats.m is not included in the qmrlab/minimal:v2.5.0, but available
// as a submodule. A remote submodule update, then addpath can be temp solution. 
// 
// The channel/value scattering works, but this script has not been tested yet
// for proper functionality.


nextflow.enable.dsl=2
include { getSubSesEntity; checkSesFolders } from './modules/bids_patterns'

params.bids = false 
params.help = false

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

entity = checkSesFolders()

if(params.bids){
    log.info "Input: $params.bids"
    bids = file(params.bids)
    derivativesDir = "$params.qmrlab_derivatives"
    log.info "Derivatives: $params.qmrlab_derivatives"
    log.info "Nextflow Work Dir: $workflow.workDir"

    Channel
    .fromPath("$derivativesDir/${entity.dirInputLevel}sub-*acq-mp2rage_T1map.nii.gz")
    .toSortedList()
    .set{maps_mp2rage}

Channel
    .fromPath("$derivativesDir/${entity.dirInputLevel}sub-*acq-MTS_T1map.nii.gz")
    .toSortedList()
    .set{maps_mts_t1}

Channel
    .fromPath("$derivativesDir/${entity.dirInputLevel}sub-*acq-MTS_MTsat.nii.gz")
    .toSortedList()
    .set{maps_mts_sat}

Channel
    .fromPath("$derivativesDir/${entity.dirInputLevel}sub-*_MTRmap.nii.gz")
    .toSortedList()
    .set{maps_mts_mtr}

Channel
    .fromPath("$derivativesDir/${entity.dirInputLevel}sub-*label-*_MP2RAGE.nii.gz")
    .toSortedList()
    .set{masks_mp2rage}

Channel
    .fromPath("$derivativesDir/${entity.dirInputLevel}sub-*label-*_MTS.nii.gz")
    .toSortedList()
    .set{masks_mts}

maps_mts_t1
    .concat(maps_mts_sat)
    .concat(maps_mts_mtr)
    .flatten()
    .toSortedList()
    .set{maps_mts}

}else{
    error "ERROR: Argument (--bids) must be passed. See USAGE."
}

process regionStatMp2rage{
    
    input:
        val input_masks from masks_mp2rage
        val input_maps from maps_mp2rage
    
    output:
        path("mp2rage.csv")
    
    script:
    """
    export masks="{\'${input_masks.join('\', \'')}\'}"
    export maps="{\'${input_maps.join('\', \'')}\'}"
    $params.runcmd "regionStats($masks,$maps,'mp2rage.csv')"
    """
}

process regionStatMTS{
    
    input:
        val input_masks from masks_mts
        val input_maps from maps_mts
    
    output:
        path("mts.csv")
    
    script:
    """
    export masks="{\'${input_masks.join('\', \'')}\'}"
    export maps="{\'${input_maps.join('\', \'')}\'}"
    $params.runcmd "regionStats($masks,$maps,'mts.csv')"
    """
}