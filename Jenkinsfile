pipeline {
  agent any
  environment {
    MVN_OPTS = '-B -DskipTests=false'
    DOCKER_IMAGE = "yourdockerhubuser/java17-demo"
    DOCKER_TAG = "${env.BUILD_NUMBER}"
    SONAR_HOST_URL = "https://sonar.example.com"
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Build & Test') { steps { sh "mvn ${MVN_OPTS} clean package" } }
    stage('SonarQube Analysis') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          sh "mvn -Dsonar.projectKey=java17-demo -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=${SONAR_TOKEN} sonar:sonar"
        }
      }
    }
    stage('Build Docker Image') { steps { sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ." } }
    stage('Push Docker Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
          sh "echo $DOCKERHUB_PASS | docker login -u $DOCKERHUB_USER --password-stdin"
          sh "docker push ${DOCKER_IMAGE}:${DOCKER_TAG}"
        }
      }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      junit 'target/surefire-reports/*.xml'
    }
  }
}
