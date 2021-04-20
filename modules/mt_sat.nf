nextflow.enable.dsl=2
params.wrapper_repo = "https://github.com/qMRLab/qMRWrappers.git"


process fitMtsatWithB1Mask{
    tag { sid }

    when:
        params.use_b1cor == true && params.use_bet == true

    input:
        tuple val(sid), file(pdw_reg), file(mtw_reg), file(t1w),\
        file(pdwj), file(mtwj), file(t1wj), file(b1map), file(mask)
        
    output:
        tuple val(sid), \
        path("${sid}_acq-MTS_T1map.nii.gz"), \
        path("${sid}_acq-MTS_MTsat.nii.gz"), \
        path("${sid}_acq-MTS_T1map.json"), \
        path("${sid}_acq-MTS_MTsat.json"), \
        path("${sid}_mt_sat.qmrlab.mat"), \
        emit: publish_mtsat

    script: 
        """
            $params.runcmd "mt_sat_neuromod('${sid}','$mtw_reg','$pdw_reg','$t1w','$mtwj','$pdwj','$t1wj','mask','$mask','b1map','$b1map','b1factor',$params.b1cor_factor); exit();"
        """
}



process fitMtsatWithB1 {
    tag { sid }

    when:
        params.use_b1cor == true && params.use_bet == false

    input:
        tuple val(sid), file(pdw_reg), file(mtw_reg), file(t1w),\
        file(pdwj), file(mtwj), file(t1wj), file(b1map)

    output:
        tuple val(sid), \
        path("${sid}_T1map.nii.gz"), \
        path("${sid}_MTsat.nii.gz"), \
        path("${sid}_T1map.json"), \
        path("${sid}_MTsat.json"), \
        path("${sid}_mt_sat.qmrlab.mat"), \
        emit: publish_mtsat

    script: 
        """
            git clone $params.wrapper_repo 
            cd qMRWrappers
            sh init_qmrlab_wrapper.sh $params.wrapper_version 
            cd ..

            $params.runcmd "addpath(genpath('qMRWrappers')); mt_sat_wrapper('$mtw_reg','$pdw_reg','$t1w','$mtwj','$pdwj','$t1wj','b1map','$b1map','b1factor',$params.b1cor_factor,'qmrlab_path','$params.qmrlab_path', 'sid','${sid}'); exit();"
        """             
}

process fitMtsatWithBet {
    tag { sid }

    when:
        params.use_b1cor == true && params.use_bet == false

    input:
        tuple val(sid), file(pdw_reg), file(mtw_reg), file(t1w),\
        file(pdwj), file(mtwj), file(t1wj), file(mask)

    output:
        tuple val(sid), \
        path("${sid}_T1map.nii.gz"), \
        path("${sid}_MTsat.nii.gz"), \
        path("${sid}_T1map.json"), \
        path("${sid}_MTsat.json"), \
        path("${sid}_mt_sat.qmrlab.mat"), \
        emit: publish_mtsat

    script: 
        """
            git clone $params.wrapper_repo 
            cd qMRWrappers
            sh init_qmrlab_wrapper.sh $params.wrapper_version 
            cd ..

            $params.runcmd "addpath(genpath('qMRWrappers')); mt_sat_wrapper('$mtw_reg','$pdw_reg','$t1w','$mtwj','$pdwj','$t1wj','mask','$mask','qmrlab_path','$params.qmrlab_path', 'sid','${sid}'); exit();"
        """
}


process fitMtsat {
    tag { sid }

    when:
        params.use_b1cor == true && params.use_bet == false

    input:
        tuple val(sid), file(pdw_reg), file(mtw_reg), file(t1w),\
        file(pdwj), file(mtwj), file(t1wj)

    output:
        tuple val(sid), \
        path("${sid}_T1map.nii.gz"), \
        path("${sid}_MTsat.nii.gz"), \
        path("${sid}_T1map.json"), \
        path("${sid}_MTsat.json"), \
        path("${sid}_mt_sat.qmrlab.mat"), \
        emit: publish_mtsat

    script: 
        """
            git clone $params.wrapper_repo 
            cd qMRWrappers
            sh init_qmrlab_wrapper.sh $params.wrapper_version 
            cd ..

            $params.runcmd "addpath(genpath('qMRWrappers')); mt_sat_wrapper('$mtw_reg','$pdw_reg','$t1w','$mtwj','$pdwj','$t1wj','qmrlab_path','$params.qmrlab_path', 'sid','${sid}'); exit();"
        """
}