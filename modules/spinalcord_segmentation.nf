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
        path("${sid}_seg-gm_mask.txt"), \
        path("${sid}_seg-wm_mask.txt"), \
        path("${sid}_seg-csf_mask.txt"), \
        emit: publish_spinal_seg

    script: 
        """
        echo "From $t2w segmented GM\n" >> ${sid}_seg-gm_mask.txt 
        echo "From $t2w segmented WM" >> ${sid}_seg-wm_mask.txt
        echo "From $t2w segmented CSF" >> ${sid}_seg-csf_mask.txt
        """
}