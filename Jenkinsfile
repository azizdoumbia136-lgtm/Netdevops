pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 40, unit: 'MINUTES')
    }

    environment {
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Lint') {
            steps {
                sh 'yamllint -c .yamllint .'
                sh 'cd ansible && ansible-lint'
                sh 'pylint --fail-under=8 scripts/'
            }
        }

        stage('SonarQube Scan') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'
                    withSonarQubeEnv('sonarqube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker') {
            steps {
                sh 'docker build -t dns-lan:${IMAGE_TAG} docker/dns-lan'
            }
        }

        stage('Trivy Scan') {
            steps {
                sh '''
                    mkdir -p reports
                    OPTS="--ignore-unfixed"
                    for IMG in dns-lan:${IMAGE_TAG} nginx:alpine; do
                        NAME=$(echo $IMG | tr ':/' '--')
                        trivy image $OPTS --severity HIGH,CRITICAL --format json \
                            -o reports/trivy-$NAME.json $IMG
                        trivy image $OPTS --severity CRITICAL --exit-code 1 $IMG
                    done
                '''
            }
        }

       stage('Deploy Test') {
            steps {
                sh 'docker compose -p netdevops-test -f docker-compose.test.yml up -d --build'
                sh 'sleep 5'
            }
        }

        stage('Tests de connectivite (test)') {
            steps {
                sh './tests/connectivity.sh test'
            }
        }

        stage('Deploy Prod') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([file(credentialsId: 'vault-pass', variable: 'VAULT_FILE')]) {
                    dir('ansible') {
                        sh 'ansible-playbook site.yml --vault-password-file "$VAULT_FILE"'
                    }
                }
            }
        }

        stage('Tests de connectivite (prod)') {
            when {
                branch 'main'
            }
            steps {
                sh './tests/connectivity.sh prod'
            }
        }
    }

    post {
        always {
            sh 'docker compose -p netdevops-test -f docker-compose.test.yml down || true'
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }

        failure {
            script {
                try {
                    mail to: 'ton.email@exemple.com',
                        subject: "ECHEC pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        body: "Voir ${env.BUILD_URL}"
                } catch (e) {
                    echo "Mail non configure : ${e.getMessage()}"
                }
            }
        }
    }
}
