process extract_brain {
    tag { sid }

    when:
        params.use_bet == true

    input:
        tuple val(sid), file(t1w)

    output:
        tuple val(sid), path("${sid}_acq-T1w_mask.nii.gz"), optional: true, \
        emit: t1w_mask_from_bet

    script:
         if (params.bet_recursive){
        """    
        bet $t1w ${sid}_acq-T1w.nii.gz -m -R -n -f $params.bet_threshold
        """}
        else{
        """    
        bet $t1w ${sid}_acq-T1w.nii.gz -m -n -f $params.bet_threshold
        """
        }

}