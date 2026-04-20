def trivy_crit_scan(String image){
    def cmd = "trivy image --severity HIGH,CRITICAL --format table ${image}"
    def proccess = cmd.execute()
    process.waitFor()

    if (process.exitValue() != 0) {
        println "Trivy scan failed: ${process.err.text}"
        return null
    }

    def output = process.text
    return new groovy.json.JsonSlurper().parseText(output)
}


