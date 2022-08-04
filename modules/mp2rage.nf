nextflow.enable.dsl=2

process fitMp2rageUni {
    tag { sid }
     
    input:
        tuple val(sid), file(mp2rage_nii), file(mp2rage_json)

    output:
        tuple val(sid), path("${sid}_acq-MP2RAGE_T1map.nii.gz"), path("${sid}_acq-MP2RAGE_T1map.json"), \
        path("${sid}_acq-MP2RAGE_R1map.nii.gz"), path("${sid}_acq-MP2RAGE_R1map.json"), \
        path("${sid}_mp2rage.qmrlab.mat"), emit: mp2rage_output

    script: 
        if (params.matlab_path_exception){
        """
            $params.matlab_path_exception -nodesktop -nosplash -r "mp2rage_neuromod('${sid}','$mp2rage_nii','$mp2rage_json'); exit();"
        """
        }else{
        """
            $params.runcmd "mp2rage_neuromod('${sid}','$mp2rage_nii','$mp2rage_json'); exit();"
        """

        }
}
