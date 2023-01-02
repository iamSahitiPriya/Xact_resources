pipeline {
    agent any
    parameters {
    string(name: 'NP_Snapshot_Id', defaultValue: '', description: '')
    string(name: 'Prod_Snapshot_Id', defaultValue: '', description: '')
    }
    stages {
        stage('Migrate Prod DB') {
            steps {
                sh "chmod +x -R ${env.WORKSPACE}"
                sh "./migrate-db-to-non-prod.sh ${NP_Snapshot_Id} ${Prod_Snapshot_Id}"
            }
        }
    }
    post {
            always {
                sh 'echo "Delete temp instance"'
                sh './post-migration-cleanup.sh'
                cleanWs notFailBuild: true
            }
    }
}
