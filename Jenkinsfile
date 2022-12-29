pipeline {
    agent any
    parameters {
    string(name: 'Snapshot_Id', defaultValue: '', description: '')
    }
    stages {
        stage('Migrate Prod DB') {
            steps {
                sh "chmod +x -R ${env.WORKSPACE}"
                sh "./migrate-db-to-non-prod.sh ${Snapshot_Id}"
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
