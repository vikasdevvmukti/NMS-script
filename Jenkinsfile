pipeline {
    agent { label 'nms-vm-agent' }

    environment {
        AZ_ACCOUNT_NAME   = credentials('AZ_ACCOUNT_NAME')
        AZ_ACCOUNT_KEY    = credentials('AZ_ACCOUNT_KEY')
        AZ_CONTAINER_NAME = credentials('AZ_CONTAINER_NAME')
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Give Permission') {
            steps {
                sh '''
                chmod +x install_nms.sh
                '''
            }
        }

        stage('Run Install Script') {
            steps {
                sh '''
                export AZ_ACCOUNT_NAME=${AZ_ACCOUNT_NAME}
                export AZ_ACCOUNT_KEY=${AZ_ACCOUNT_KEY}
                export AZ_CONTAINER_NAME=${AZ_CONTAINER_NAME}

                ./install_nms.sh
                '''
            }
        }

    }

    post {
        success {
            echo "NMS Deployment Completed Successfully"
        }
        failure {
            echo "Deployment Failed - Check Logs"
        }
    }
}
