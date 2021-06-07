// Enable DSL2 so that this can be imported as a module
nextflow.enable.dsl=2

/* This PLACEHOLDER process is to explain the relationship 
between the files emitted by the input channels, process and  
how those files are process to emit outputs */ 

process MTS_Align_SpinalCord{
    tag { sid }

    input:
        tuple val(sid), file(pdw), file(mtw), file(t1w)

    output:
        tuple val(sid), \
        path("${sid}_MTSAT_example.txt"), \
        emit: publish_spinal_mtsat

    script: 
        """
        echo "sct_parameter was $params.sct_parameter\n" >> ${sid}_MTSAT_example.txt
        echo "the other one was $params.sct_another_parameter\n" >> ${sid}_MTSAT_example.txt
        echo "sid is ${sid}\n" >> ${sid}_MTSAT_example.txt
        echo "MTon is $mtw\n" >> ${sid}_MTSAT_example.txt
        echo "MToff is $pdw\n" >> ${sid}_MTSAT_example.txt
        echo "T1w is $t1w\n" >> ${sid}_MTSAT_example.txt
        echo "ENV vars can be captured: $PATH\n" >> ${sid}_MTSAT_example.txt
        """
}