pipeline {
  agent any

  stages {

    stage('Git Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/Sougata1813/Hello.git'
      }
    }

    stage('Unit Testing') {
      steps {
        sh 'mvn test'
      }
    }

    stage('Integration Testing') {
      steps {
        sh 'mvn verify -DskipUnitTests'
      }
    }

    stage('Maven Build') {
      steps {
        sh 'mvn clean package spring-boot:repackage -DskipTests'
      }
    }

    stage('Static Code Analysis') {
      steps {
        script {
          withSonarQubeEnv('sonarqube') {
            sh 'mvn sonar:sonar'
          }
        }
      }
    }

    stage('Quality Gate Check') {
      steps {
        script {
          waitForQualityGate abortPipeline: false, credentialsId: 'sonarqube'
        }
      }
    }

    stage('Docker Build Image') {
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"
          sh "docker build -t cicdpipeline:${buildTag} ."
        }
      }
    }

    stage('Deploy Docker Container') {
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"
          def containerName = "cicdpipeline_app"

          sh """
            echo "Stopping old container if exists..."
            docker rm -f ${containerName} || true

            echo "Starting new container from image cicdpipeline:${buildTag}"
            docker run -d --name ${containerName} -p 9090:8080 cicdpipeline:${buildTag}
          """
        }
      }
    }
  }
}
