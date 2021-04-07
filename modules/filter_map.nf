nextflow.enable.dsl=2

process smoothB1WithMask {
    tag { sid }
     
    when:
        params.use_b1cor == true && params.use_bet == true

    input:
        tuple val(sid), file(b1aligned), file(mask)

    output:
        tuple val(sid), path("${sid}_B1plusmap_filtered.nii.gz"), path("${sid}_B1plusmap_filtered.json"), \
        optional: true, emit: b1_filtered_w_mask

    script: 
        if (params.matlab_path_exception){
        """
            git clone $params.wrapper_repo 
            cd qMRWrappers
            sh init_qmrlab_wrapper.sh $params.wrapper_version 
            cd ..

            $params.matlab_path_exception -nodesktop -nosplash -r "addpath(genpath('qMRWrappers')); filter_map_wrapper('$b1aligned', 'mask', '$mask', 'type','$params.b1_filter_type','order',$params.b1_filter_order,'dimension','$params.b1_filter_dimension','size',$params.b1_filter_size,'qmrlab_path','$params.qmrlab_path_exception','siemens','$params.b1_filter_siemens', 'sid','${sid}'); exit();" 
        """
        }else{
        """
            git clone $params.wrapper_repo 
            cd qMRWrappers
            sh init_qmrlab_wrapper.sh $params.wrapper_version 
            cd ..

            $params.runcmd "addpath(genpath('qMRWrappers')); filter_map_wrapper('$b1aligned', 'mask', '$mask', 'type','$params.b1_filter_type','order',$params.b1_filter_order,'dimension','$params.b1_filter_dimension','size',$params.b1_filter_size,'qmrlab_path','$params.qmrlab_path','siemens','$params.b1_filter_siemens', 'sid','${sid}'); exit();" 
        """

        }

}

process smoothB1WithoutMask {
    tag { sid }

    if (!params.matlab_path_exception){
    container 'qmrlab/minimal:v2.3.1'
    }

    when:
        params.use_b1cor == true && params.use_bet == false

    input:
        tuple val(sid), file(b1aligned)
    
    output:
        tuple val(sid), path("${sid}_B1plusmap_filtered.nii.gz"), path("${sid}_B1plusmap_filtered.json"), \
        optional: true, emit: b1_filtered_wo_mask
        
    script:
    if (params.matlab_path_exception){
        """
            git clone $params.wrapper_repo 
            cd qMRWrappers
            sh init_qmrlab_wrapper.sh $params.wrapper_version 
            cd ..

            $params.matlab_path_exception -nodesktop -nosplash -r "addpath(genpath('qMRWrappers')); filter_map_wrapper('$b1aligned','type','$params.b1_filter_type','order',$params.b1_filter_order,'dimension','$params.b1_filter_dimension','size',$params.b1_filter_size,'qmrlab_path','$params.qmrlab_path_exception','siemens','$params.b1_filter_siemens', 'sid','${sid}'); exit();" 
        """
        }else{
        """
            git clone $params.wrapper_repo 
            cd qMRWrappers
            sh init_qmrlab_wrapper.sh $params.wrapper_version 
            cd ..
            
            $params.runcmd "addpath(genpath('qMRWrappers')); filter_map_wrapper('$b1aligned', 'type','$params.b1_filter_type','order',$params.b1_filter_order,'dimension','$params.b1_filter_dimension','size',$params.b1_filter_size,'qmrlab_path','$params.qmrlab_path','siemens','$params.b1_filter_siemens', 'sid','${sid}'); exit();" 
        """

    }

}
