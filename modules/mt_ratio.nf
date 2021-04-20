process fitMtratioWithMask{
    tag { sid }

    input:
        tuple val(sid), file(pdw_reg), file(mtw_reg), file(mask)
        
    output:
        tuple val(sid), \
        path("${sid}_MTRmap.nii.gz"), \
        path("${sid}_MTRmap.json"), \
        path("${sid}_mt_ratio.qmrlab.mat"), \
        emit: mtratio_output

    script: 
        """
            $params.runcmd "mt_ratio_neuromod('${sid}','$mtw_reg','$pdw_reg','mask','$mask'); exit();"
        """
}
