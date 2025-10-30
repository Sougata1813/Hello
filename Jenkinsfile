pipeline{

  agent any

  stages{

    stage('git checkout'){

      steps{
        git branch: 'main', url: 'https://github.com/Sougata1813/Hello.git'
      }
    }
    stage('unit testing'){

      steps{
        sh 'mvn test'
      }
    }
    stage('integration testing'){

      steps{
        sh 'mvn verify -DskipUnitTests'
      }
    }
    stage('Maven Build'){

      steps{
        sh 'mvn clean install'
      }
    }
    stage('Static code analysis'){

      steps{

        script{

            withSonarQubeEnv('sonarqube') {
            sh 'mvn clean package sonar:sonar'
          }

        }
       
      }
    }
    stage('quality get status'){

      steps{

        script{
          waitForQualityGet abourtPipeline: false, credentialsId: 'sonarqube'

        }
       
      }
    }
  }

}