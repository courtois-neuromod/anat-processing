nextflow.enable.dsl=2

process mtsat_align_inputs {
    // This notation allows deferring the evaluation of sid 
    // until the process is executed, so that it is in the scope
    tag { sid }

    input:
        tuple val(sid), file(pdw), file(pdwj), file(mtw), file(mtwj), file(t1w), file(t1wj)
    
    output:
        tuple val(sid),\
        path("${sid}_acq-MTon_MTS_aligned.nii.gz"), \
        path("${sid}_acq-MToff_MTS_aligned.nii.gz"), \
        path("${sid}_mtw_to_t1w_displacement.*.mat"), \
        path("${sid}_pdw_to_t1w_displacement.*.mat"), \
        emit: mtsat_from_alignment

    script:
        """
        touch ${sid}_acq-MTon_MTS_aligned.nii.gz
        touch ${sid}_acq-MToff_MTS_aligned.nii.gz
        touch ${sid}_mtw_to_t1w_displacement.aa.mat
        touch ${sid}_pdw_to_t1w_displacement.aa.mat
        """
}

/*
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
*/