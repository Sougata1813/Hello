pipeline {
  agent any

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }

  environment {
    IMAGE_NAME = "cicdpipeline"
    STABLE_FILE = "last_stable_commit.txt"
    GIT_CREDENTIALS_ID = "github-token"   // 🔹 Replace with your Jenkins credential ID
    GIT_REPO = "https://github.com/Sougata1813/Hello.git"
  }

  stages {

    // 1️⃣ Git Checkout
    stage('Git Checkout') {
      steps {
        echo "🔄 Checking out source code..."
        git branch: 'main', url: "${GIT_REPO}"
      }
    }

    // 2️⃣ Unit Testing
    stage('Unit Testing') {
      steps {
        echo "🧪 Running Unit Tests..."
        sh 'mvn test 2>&1 | tee build.log'
      }
    }

    // 3️⃣ Integration Testing
    stage('Integration Testing') {
      steps {
        echo "🔬 Running Integration Tests..."
        sh 'mvn verify -DskipUnitTests 2>&1 | tee -a build.log'
      }
    }

    // 4️⃣ Maven Build — detect failure and rollback
    stage('Maven Build') {
      steps {
        script {
          echo "🏗️ Building Maven project..."

          // Capture real Maven exit code
          def buildStatus = sh(
            script: 'mvn clean package spring-boot:repackage -DskipTests 2>&1 | tee build.log; exit ${PIPESTATUS[0]}',
            returnStatus: true
          )

          if (buildStatus != 0) {
            echo "❌ Maven build failed — initiating rollback sequence..."

            // Detect the failed file type (.java, .sql, .xml, .prc, .pck)
            def failedFile = sh(
              script: "grep -Eo '/[^ ]+\\.(java|sql|xml|prc|pck)' ${env.WORKSPACE}/build.log | head -1 || true",
              returnStdout: true
            ).trim()

            if (failedFile) {
              echo "⚠️ Build failed due to file: ${failedFile}"

              // Rollback logic
              if (fileExists("${STABLE_FILE}")) {
                def lastCommit = readFile("${STABLE_FILE}").trim()
                echo "🔁 Rolling back ${failedFile} to commit ${lastCommit}"

                withCredentials([usernamePassword(credentialsId: "${GIT_CREDENTIALS_ID}", usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                  sh """
                    git fetch origin main
                    git checkout ${lastCommit} -- ${failedFile}
                    git config user.name "Jenkins"
                    git config user.email "jenkins@local"
                    git add ${failedFile}
                    git commit -m "Build Failure - Rolled back ${failedFile} to previous stable commit"
                    git push https://${GIT_USER}:${GIT_PASS}@github.com/Sougata1813/Hello.git HEAD:main
                  """
                }
              } else {
                echo "⚠️ No stable commit file found — cannot rollback source file."
              }
            } else {
              echo "⚠️ Could not detect failed file automatically. Skipping file rollback."
            }

            // Stop pipeline immediately (skip Docker)
            error("⛔ Maven build failed — rollback executed.")
          } else {
            echo "✅ Maven build successful — saving current commit as stable."
            sh 'git rev-parse HEAD > ${STABLE_FILE}'
          }
        }
      }
    }

    // 5️⃣ Static Code Analysis
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

    // 6️⃣ Quality Gate Check
    stage('Quality Gate Check') {
      steps {
        script {
          echo "⏳ Waiting for SonarQube Quality Gate result..."
          waitForQualityGate abortPipeline: false, credentialsId: 'sonarqube'
        }
      }
    }

    // 7️⃣ Docker Build
    stage('Docker Build Image') {
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"
          echo "🐳 Building Docker image: ${IMAGE_NAME}:${buildTag}"
          sh "docker
