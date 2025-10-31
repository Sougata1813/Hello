pipeline {
  agent any

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }

  environment {
    IMAGE_NAME = "cicdpipeline"
    STABLE_FILE = "last_stable_commit.txt"
    GIT_CREDENTIALS_ID = "github-token"   // 🔹 Create Jenkins credential (type: Username + Password or PAT)
  }

  stages {
    stage('Git Checkout') {
      steps {
        echo "🔄 Checking out source code..."
        git branch: 'main', url: 'https://github.com/Sougata1813/Hello.git'
      }
    }

    stage('Unit Testing') {
      steps {
        echo "🧪 Running Unit Tests..."
        sh 'mvn test'
      }
    }

    stage('Integration Testing') {
      steps {
        echo "🔬 Running Integration Tests..."
        sh 'mvn verify -DskipUnitTests'
      }
    }

    stage('Maven Build') {
      steps {
        echo "🏗️ Building Maven project..."
        sh 'mvn clean package spring-boot:repackage -DskipTests'
      }
    }

    stage('Static Code Analysis') {
      steps {
        script {
          echo "📊 Running SonarQube Analysis..."
          withSonarQubeEnv('sonarqube') {
            sh 'mvn sonar:sonar'
          }
        }
      }
    }

    stage('Quality Gate Check') {
      steps {
        script {
          echo "⏳ Waiting for SonarQube Quality Gate result..."
          waitForQualityGate abortPipeline: false, credentialsId: 'sonarqube'
        }
      }
    }

    stage('Docker Build Image') {
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"
          echo "🐳 Building Docker image: ${IMAGE_NAME}:${buildTag}"
          sh "docker build -t ${IMAGE_NAME}:${buildTag} ."
        }
      }
    }

    stage('Deploy Docker Container') {
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"
          def containerName = "${IMAGE_NAME}_app"

          echo "🚀 Deploying Docker container..."
          sh """
            echo "Stopping old container if it exists..."
            docker rm -f ${containerName} || true

            echo "Starting new container from image ${IMAGE_NAME}:${buildTag}"
            docker run -d --name ${containerName} -p 9090:8080 ${IMAGE_NAME}:${buildTag}
          """

          // Save stable commit after successful deploy
          sh '''
            echo "💾 Saving last stable commit..."
            git rev-parse HEAD > ${STABLE_FILE}
          '''
        }
      }
    }

    stage('Docker Cleanup (Keep Last 3 Images)') {
      steps {
        script {
          echo "🧹 Cleaning up old Docker images..."
          sh '''
            images_to_delete=$(docker images --format "{{.Repository}}:{{.Tag}}" ${IMAGE_NAME} | sort -r | tail -n +4)
            if [ -n "$images_to_delete" ]; then
              echo "Removing old images:"
              echo "$images_to_delete" | xargs -r docker rmi -f
            else
              echo "No old images to remove."
            fi
          '''
        }
      }
    }
  }

  post {
    always {
        echo "🏁 Pipeline execution completed (success or failure)."
    }
    failure {
        echo "❌ Pipeline failed — initiating rollback sequence..."

        script {
            // Try to find which file caused the build to fail (.java, .sql, .xml, .prc, .pck)
            echo "🔍 Detecting failed file from build logs..."
            def failedFile = sh(
                script: "grep -Eo '/[^ ]+\\.(java|sql|xml|prc|pck)' ${env.WORKSPACE}/build.log | head -1 || true",
                returnStdout: true
            ).trim()

            if (failedFile) {
                echo "⚠️ Build failed due to file: ${failedFile}"
                sh """
                    git config user.name "Jenkins"
                    git config user.email "jenkins@local"
                    echo "🔁 Rolling back ${failedFile} to previous commit..."
                    git checkout HEAD~1 -- ${failedFile}
                    git commit -am "Build Failure - rolled back ${failedFile}"
                    git push origin main
                """
            } else {
                echo "⚠️ Could not detect failed file automatically. Skipping rollback."
            }

            // Optional: Redeploy last stable Docker image
            echo "🔁 Attempting Docker rollback..."
            sh '''
                container_name="cicdpipeline_app"
                prev_image=$(docker images --format "{{.Repository}}:{{.Tag}}" cicdpipeline | sort -r | sed -n 2p)
                if [ -n "$prev_image" ]; then
                    echo "Rolling back to previous Docker image: $prev_image"
                    docker rm -f $container_name || true
                    docker run -d --name $container_name -p 9090:8080 $prev_image
                else
                    echo "⚠️ No previous Docker image found for rollback."
                fi
            '''
        }
        
    }
  }
}
