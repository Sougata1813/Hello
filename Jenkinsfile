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
      failure {
        script {
          echo "❌ Pipeline failed — initiating rollback sequence..."

          echo "🔍 Detecting modified files in current commit..."
          def changedFiles = sh(script: 'git diff --name-only HEAD~1 HEAD || true', returnStdout: true).trim().split("\\n")

          if (changedFiles.size() == 0) {
            echo "⚠️ No changed files detected — skipping rollback."
          } else {
            echo "🗂️ Files changed in this build: ${changedFiles}"

            changedFiles.each { file ->
              if (file ==~ /.*\\.(java|sql|xml|prc|pck)$/) {
                echo "🔁 Rolling back file: ${file}"
                withCredentials([usernamePassword(credentialsId: "${GIT_CREDENTIALS_ID}", usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                  sh """
                    set -e
                    git fetch origin main
                    last_commit=\$(cat ${STABLE_FILE} 2>/dev/null || echo "HEAD~1")
                    echo "Restoring from commit \$last_commit"
                    git checkout \$last_commit -- ${file} || echo "⚠️ Could not revert ${file}"
                    git config user.name "Sougata1813"
                    git config user.email "sougatapratihar50@gmail.com"
                    git add ${file} || true
                    git commit -m "Build Failure - Rolled back ${file} to last stable commit" || echo "⚠️ Nothing to commit"
                    git push https://${GIT_USER}:${GIT_PASS}@github.com/Sougata1813/Hello.git HEAD:main || echo "⚠️ Push failed, check credentials"
                  """
                }
              }
            }
          }

          // Docker rollback
          sh '''
            echo "🔁 Attempting Docker rollback..."
            container_name="${IMAGE_NAME}_app"
            prev_image=$(docker images --format "{{.Repository}}:{{.Tag}}" ${IMAGE_NAME} | sort -r | sed -n '2p')
            if [ -n "$prev_image" ]; then
              echo "Rolling back to previous Docker image: $prev_image"
              docker rm -f $container_name || true
              docker run -d --name $container_name -p 9090:8080 $prev_image
            else
              echo "⚠️ No previous image found to roll back."
            fi
          '''
        }
      }

      success {
        echo "✅ Pipeline succeeded — build marked as stable."
      }

      always {
        echo "🏁 Pipeline execution completed (success or failure)."
      }
    }
}
