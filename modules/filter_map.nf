nextflow.enable.dsl=2

process smoothB1WithMask {
    tag { sid }
     
    when:
        params.use_bet == true

    input:
        tuple val(sid), file(b1aligned), file(mask)

    output:
        tuple val(sid), path("${sid}_TB1map.nii.gz"), path("${sid}_TB1map.json"), \
        optional: true, emit: b1_filtered

    script: 
        if (params.matlab_path_exception){
        """
            $params.matlab_path_exception -nodesktop -nosplash -r "filter_map_neuromod('${sid}','$b1aligned','mask', '$mask','type','$params.b1_filter_type','order',$params.b1_filter_order,'dimension','$params.b1_filter_dimension','size',$params.b1_filter_size,'qmrlab_path','$params.qmrlab_path_exception','siemens',$params.b1_filter_siemens); exit();" 
        """
        }else{
        """
            $params.runcmd "filter_map_neuromod('${sid}','$b1aligned','mask', '$mask','type','$params.b1_filter_type','order',$params.b1_filter_order,'dimension','$params.b1_filter_dimension','size',$params.b1_filter_size,'qmrlab_path','$params.qmrlab_path_exception','siemens',$params.b1_filter_siemens); exit();" 
        """

        }

}

process smoothB1WithoutMask {
    tag { sid }
     
    when:
        params.use_bet == false

    input:
        tuple val(sid), file(b1aligned)

    output:
        tuple val(sid), path("${sid}_TB1map.nii.gz"), path("${sid}_TB1map.json"), \
        optional: true, emit: b1_filtered

    script: 
        if (params.matlab_path_exception){
        """
            $params.matlab_path_exception -nodesktop -nosplash -r "filter_map_neuromod('${sid}','$b1aligned','type','$params.b1_filter_type','order',$params.b1_filter_order,'dimension','$params.b1_filter_dimension','size',$params.b1_filter_size,'qmrlab_path','$params.qmrlab_path_exception','siemens',$params.b1_filter_siemens); exit();" 
        """
        }else{
        """
            $params.runcmd "filter_map_neuromod('${sid}','$b1aligned','type','$params.b1_filter_type','order',$params.b1_filter_order,'dimension','$params.b1_filter_dimension','size',$params.b1_filter_size,'qmrlab_path','$params.qmrlab_path_exception','siemens',$params.b1_filter_siemens); exit();" 
        """

        }

}