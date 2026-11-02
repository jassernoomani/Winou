// Winou CI/CD, run by the Jenkins in deploy/jenkins/ on the home server for every push to main:
// tests -> SonarCloud analysis and quality gate -> redeploy the server -> new APK if the app changed.
pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    parameters {
        booleanParam(name: 'FORCE_APK', defaultValue: false,
                description: 'Build and publish the APK even if mobile/ did not change')
        booleanParam(name: 'SKIP_DEPLOY', defaultValue: false,
                description: 'Only test and analyse; leave the server and the APK alone')
    }

    stages {
        stage('Tests') {
            parallel {
                stage('Backend') {
                    environment {
                        JAVA_HOME = "${env.JDK25_HOME}"
                    }
                    steps {
                        dir('backend') {
                            // Unit + Testcontainers tests, then the JaCoCo coverage report
                            sh 'sh mvnw -B -ntp verify'
                        }
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'backend/target/surefire-reports/*.xml'
                        }
                    }
                }
                stage('ML service') {
                    steps {
                        dir('ml-service') {
                            sh '''
                                venv="$JENKINS_HOME/caches/ml-venv"
                                [ -x "$venv/bin/python" ] || python3 -m venv "$venv"
                                . "$venv/bin/activate"
                                # CPU PyTorch, same versions as the Dockerfile
                                torch_pins=$(sed -n 's/^RUN pip install \\(torch==[^ ]* torchvision==[^ ]*\\).*/\\1/p' Dockerfile)
                                pip install -q $torch_pins --index-url https://download.pytorch.org/whl/cpu
                                pip install -q -r requirements-dev.txt pytest-cov
                                # The "models" tests download real weights; the fake-pipeline tests cover the API
                                pytest -m "not models" --cov=app --cov-report=xml:coverage.xml --junitxml=test-results.xml
                            '''
                        }
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'ml-service/test-results.xml'
                        }
                    }
                }
                stage('Mobile') {
                    steps {
                        dir('mobile') {
                            sh '''
                                flutter pub get
                                flutter analyze --no-fatal-infos
                                flutter test --coverage
                            '''
                        }
                    }
                }
            }
        }

        stage('SonarCloud') {
            steps {
                withCredentials([string(credentialsId: 'sonarcloud-token', variable: 'SONAR_TOKEN')]) {
                    // Settings in sonar-project.properties; fails the build if the quality gate fails
                    sh 'sonar-scanner -Dsonar.qualitygate.wait=true'
                }
            }
        }

        stage('Deploy') {
            when {
                expression { !params.SKIP_DEPLOY }
            }
            steps {
                script {
                    def rc = sh(script: 'bash deploy/jenkins/deploy.sh', returnStatus: true)
                    if (rc == 2) {
                        unstable('Not deployed: the laptop copy of the repo is not at this commit (see log)')
                    } else if (rc != 0) {
                        error("Deploy failed (exit ${rc})")
                    }
                }
            }
        }

        stage('APK') {
            when {
                allOf {
                    expression { !params.SKIP_DEPLOY }
                    anyOf {
                        expression { params.FORCE_APK }
                        changeset 'mobile/**'
                    }
                }
            }
            steps {
                sh 'bash deploy/jenkins/build-apk.sh'
                archiveArtifacts artifacts: 'mobile/build/app/outputs/flutter-apk/app-release.apk', fingerprint: true
            }
        }
    }
}
