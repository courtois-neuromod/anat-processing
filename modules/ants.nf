nextflow.enable.dsl=2

process alignMtsatInputs {
    // This notation allows deferring the evaluation of sid 
    // until the process is executed, so that it is in the scope
    tag { sid }

    input:
        tuple val(sid), file(pdw), file(mtw), file(t1w)
    
    output:
        tuple val(sid),\
        path("${sid}_acq-MToff_MTS_aligned.nii.gz"), \
        path("${sid}_acq-MTon_MTS_aligned.nii.gz"), \
        path("${sid}_pdw_to_t1w_displacement.*.mat"), \
        path("${sid}_mtw_to_t1w_displacement.*.mat"), \
        emit: mtsat_from_alignment

    script:
        """
                antsRegistration -d $params.ants_dim \
                            --float 0 \
                            -o [${sid}_mtw_to_t1w_displacement.mat,${sid}_acq-MTon_MTS_aligned.nii.gz] \
                            --transform $params.ants_transform \
                            --metric $params.ants_metric[$t1w,$mtw,$params.ants_metric_weight, $params.ants_metric_bins,$params.ants_metric_sampling,$params.ants_metric_samplingprct] \
                            --convergence $params.ants_convergence \
                            --shrink-factors $params.ants_shrink \
                            --smoothing-sigmas $params.ants_smoothing

        antsRegistration -d $params.ants_dim \
                            --float 0 \
                            -o [${sid}_pdw_to_t1w_displacement.mat,${sid}_acq-MToff_MTS_aligned.nii.gz] \
                            --transform $params.ants_transform \
                            --metric $params.ants_metric[$t1w,$pdw,$params.ants_metric_weight, $params.ants_metric_bins,$params.ants_metric_sampling,$params.ants_metric_samplingprct] \
                            --convergence $params.ants_convergence \
                            --shrink-factors $params.ants_shrink \
                            --smoothing-sigmas $params.ants_smoothing
        """
}

/*

        """

        touch ${sid}_acq-MTon_MTS_aligned.nii.gz
        touch ${sid}_acq-MToff_MTS_aligned.nii.gz
        touch ${sid}_mtw_to_t1w_displacement.aa.mat
        touch ${sid}_pdw_to_t1w_displacement.aa.mat
*/

process resampleB1 {
    tag { sid }

    when:
        params.use_b1cor == true

    input:
        tuple val(sid), file(t1w), file(b1raw)
        
    output:
        tuple val(sid), path("${sid}_B1plusmap_aligned.nii.gz"), optional: true, \
        emit: b1_resampled

    script:
        """
        antsApplyTransforms -d 3 -e 0 -i $b1raw \
                            -r $t1w \
                            -o ${sid}_B1plusmap_aligned.nii.gz \
                            -t identity
        """

}

process generateRegionMasks {
    tag { sid }
    
    input:
        tuple val(sid), file(t1highres), file(t1mts), file(t1mp2rage)
        
    output:
        tuple val(sid), \
        path("${sid}_label-GM_MTS.nii.gz"), \
        path("${sid}_label-WM_MTS.nii.gz"), \
        path("${sid}_label-GM_MP2RAGE.nii.gz"), \
        path("${sid}_label-WM_MP2RAGE.nii.gz"), \
        path("${sid}_t1whighres_to_mts_displacement.mat0GenericAffine.mat"),\
        path("${sid}_t1whighres_to_mp2rage_displacement.mat0GenericAffine.mat"),\
        emit: region_masks

    script:
        """
        mkdir -p /usr/share/fsl/5.0/data/standard/
        wget -nc -O MNI152_T1_2mm_brain.nii.gz https://osf.io/bxwfm/download
        cp MNI152_T1_2mm_brain.nii.gz /usr/share/fsl/5.0/data/standard/MNI152_T1_2mm_brain.nii.gz
        
        fsl_anat -i $t1highres -o ./seg --noreorient --noreg --nononlinreg --nosubcortseg
                
        antsRegistration -d $params.ants_dim \
                    --float 0 \
                    -o [${sid}_t1whighres_to_mts_displacement.mat,${sid}_t1whighres_to_mts_aligned.nii.gz] \
                    --transform $params.ants_transform \
                    --metric $params.ants_metric[$t1mts,./seg.anat/T1.nii.gz,$params.ants_metric_weight, $params.ants_metric_bins,$params.ants_metric_sampling,$params.ants_metric_samplingprct] \
                    --convergence $params.ants_convergence \
                    --shrink-factors $params.ants_shrink \
                    --smoothing-sigmas $params.ants_smoothing

        antsApplyTransforms -d 3 -e 0 -i ./seg.anat/T1_fast_pve_1.nii.gz -r $t1mts -o ${sid}_label-GM_MTS.nii.gz -t ${sid}_t1whighres_to_mts_displacement.mat0GenericAffine.mat
        antsApplyTransforms -d 3 -e 0 -i ./seg.anat/T1_fast_pve_2.nii.gz -r $t1mts -o ${sid}_label-WM_MTS.nii.gz -t ${sid}_t1whighres_to_mts_displacement.mat0GenericAffine.mat

        antsRegistration -d $params.ants_dim \
            --float 0 \
            -o [${sid}_t1whighres_to_mp2rage_displacement.mat,${sid}_t1whighres_to_mp2rage_aligned.nii.gz] \
            --transform $params.ants_transform \
            --metric $params.ants_metric[$t1mp2rage,./seg.anat/T1.nii.gz,$params.ants_metric_weight, $params.ants_metric_bins,$params.ants_metric_sampling,$params.ants_metric_samplingprct] \
            --convergence $params.ants_convergence \
            --shrink-factors $params.ants_shrink \
            --smoothing-sigmas $params.ants_smoothing

        antsApplyTransforms -d 3 -e 0 -i ./seg.anat/T1_fast_pve_1.nii.gz -r $t1mp2rage -o ${sid}_label-GM_MP2RAGE.nii.gz -t ${sid}_t1whighres_to_mp2rage_displacement.mat0GenericAffine.mat
        antsApplyTransforms -d 3 -e 0 -i ./seg.anat/T1_fast_pve_2.nii.gz -r $t1mp2rage -o ${sid}_label-WM_MP2RAGE.nii.gz -t ${sid}_t1whighres_to_mp2rage_displacement.mat0GenericAffine.mat
        """

}
