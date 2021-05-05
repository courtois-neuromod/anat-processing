// Enable DSL2 so that this can be imported as a module
nextflow.enable.dsl=2

/* This PLACEHOLDER process is to explain the relationship 
between the files emitted by the input channels, process and  
how those files are process to emit outputs */ 

process T2_Segment_SpinalCord{
    tag { sid }

    input:
        tuple val(sid), file(t2w)

    output:
        tuple val(sid), \
        path("${sid}_bp-cspine_T2w_seg.nii.gz"), \
        emit: publish_spinal_seg

    script: 
        """
        sct_deepseg_sc -i $t2w -c t2 -qc $params.qcDir -qc-subject ${sid}
        """

}