pipeline {
  agent any

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }

  environment {
    IMAGE_NAME = "cicdpipeline"
    STABLE_FILE = "last_stable_commit.txt"
    GIT_CREDENTIALS_ID = "github-token"   // Jenkins credential (PAT or Username + Password)
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
        sh 'mvn test 2>&1 | tee build.log'
      }
    }

    stage('Maven Build') {
      steps {
        script {
          echo "🏗️ Running Maven Build..."
          // Capture the build result (do NOT stop Jenkins immediately)
          def buildStatus = sh(script: 'mvn clean package spring-boot:repackage -DskipTests 2>&1 | tee -a build.log', returnStatus: true)

          if (buildStatus != 0) {
            echo "❌ Maven build failed. Triggering rollback for failed file..."
            rollbackFailedFileAndDocker()
            error("⛔ Build failed in Maven stage. Rollback completed.")
          } else {
            echo "✅ Maven build succeeded."
          }
        }
      }
    }

    stage('Static Code Analysis') {
      steps {
        script {
          echo "📊 Running SonarQube Analysis..."
          withSonarQubeEnv('sonarqube') {
            sh 'mvn sonar:sonar 2>&1 | tee -a build.log'
          }
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
            docker rm -f ${containerName} || true
            docker run -d --name ${containerName} -p 9090:8080 ${IMAGE_NAME}:${buildTag}
          """

          // Save stable commit SHA after successful deployment
          sh 'git rev-parse HEAD > ${STABLE_FILE}'
        }
      }
    }

    stage('Docker Cleanup') {
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
      echo "🏁 Pipeline completed."
    }
    success {
      echo "✅ Build successful — this is now the stable commit."
    }
    failure {
      echo "❌ Build failed — rollback handled already."
    }
  }
}

//
// --- 🔁 Rollback Logic ---
//
def rollbackFailedFileAndDocker() {
  echo "🔍 Detecting failed file from build logs..."
  def failedFile = sh(
    script: "grep -Eo '/[^ ]+\\.(java|sql|xml|prc|pck)' ${env.WORKSPACE}/build.log | head -1 || true",
    returnStdout: true
  ).trim()

  if (failedFile) {
    echo "⚠️ Build failed due to file: ${failedFile}"

    if (fileExists("last_stable_commit.txt")) {
      def lastCommit = readFile("last_stable_commit.txt").trim()
      echo "🔁 Rolling back ${failedFile} to commit ${lastCommit}"

      withCredentials([usernamePassword(credentialsId: "github-token", usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
        sh """
          git fetch origin main
          git checkout ${lastCommit} -- ${failedFile}
          git config user.name "Sougata1813"
          git config user.email "sougatapratihar50@gmail.com"
          git add ${failedFile}
          git commit -m "Build Failure - Rolled back ${failedFile} to stable commit ${lastCommit}"
          git push https://${GIT_USER}:${GIT_PASS}@github.com/Sougata1813/Hello.git HEAD:main
        """
      }
    } else {
      echo "⚠️ No stable commit file found — cannot rollback code."
    }
  } else {
    echo "⚠️ Could not detect failed file automatically. Skipping file rollback."
  }

  echo "🔁 Rolling back Docker image..."
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
