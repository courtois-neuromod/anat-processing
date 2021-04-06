def checkSesFolders() {
    def Map entity = [:]
    // Check if subject folders contain sessions ==================================
    isSesFolder = true
    // Emit false otherwise CHECKS ANAT FOLDER ONLY
    Channel.fromPath( "$params.bids/sub*/ses*", type: 'dir', checkIfExists: true )
            .ifEmpty { isSesFolder=false}

    // Depending on whether the dataset uses session-level folders, 
    // file-depths must be dynamically configured. 
    // This is controlled by the ses_directory parameter.
    // FitResultsSave_BIDS knows 
    // how to deal with that based on SID passed by nextflow 
    // when setenv('NEXTFLOW','1')

    if (isSesFolder){
        println "Session-level organization has been ENABLED."
        entity.dirInputLevel = "**/**/"
        entity.qmrlabSesFlag = "true"
    }else{
        println "Session-level organization has been DISABLED."
        entity.dirInputLevel = "**/"
        entity.qmrlabSesFlag = "false"
    }

    return entity
}


def getSubSesEntity(sid) {
    def Map out = [:]
    out.sub = ("${sid}" =~ /(sub[^_]+)/)[0][0]
    if (isSesFolder){
        out.ses = ("${sid}" =~ /(ses[^_]+)/)[0][0]
        out.ses = out.ses + "/"
    }else{
        out.ses = ''
    }
    return out
}