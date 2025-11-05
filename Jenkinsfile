pipeline {
  agent any

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }

  environment {
    IMAGE_NAME = "cicdpipeline"
    STABLE_FILE = "last_stable_commit.txt"
    GIT_CREDENTIALS_ID = "github-token"
    DOCKER_HUB_CREDENTIALS_ID = "docker-token"   // <-- Add your Docker Hub credential ID here
    DOCKERHUB_USER = "sougata18"             // <-- Replace with your Docker Hub username
  }

  stages {

    stage('Git Checkout') {
      steps {
        echo "🔄 Checking out source code..."
        git branch: 'main', url: 'https://github.com/Sougata1813/Hello.git'
      }
    }

    stage('Unit Testing & Maven Build') {
      steps {
        script {
          echo "🏗️ Running Maven Build & Tests..."
          try {
            sh '''
              echo "Cleaning and packaging application..."
              mvn clean test package spring-boot:repackage -DskipTests=false 2>&1 | tee build.log
            '''
            def jarStatus = sh(script: 'ls -1 target/*.jar 2>/dev/null | wc -l', returnStdout: true).trim()
            if (jarStatus == '0') {
              error("❌ Maven build did not produce a JAR file — check your pom.xml or source files.")
            }
            echo "✅ Maven build successful — JAR found in target/."
          } catch (err) {
            echo "❌ Maven build failed! Check build.log for details."
            error("❌ Maven build failed.")
          }
        }
      }
    }

    stage('Database Compilation') {
      steps {
        script {
          echo "💾 Compiling Database Scripts..."
          try {
            sh '''
              for f in $(find . -type f -name "*.sql" -o -name "*.prc" -o -name "*.pck" -o -name "*.tst"); do
                echo "Compiling $f"
                if grep -q "FAILME" "$f"; then
                  echo "Error in $f"
                  exit 1
                fi
              done | tee -a build.log
            '''
          } catch (err) {
            error("❌ Database compilation failed!")
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

    stage('Quality Gate Check') {
      steps {
        script {
          echo "⏳ Waiting for SonarQube Quality Gate..."
          waitForQualityGate abortPipeline: false, credentialsId: 'sonarqube'
        }
      }
    }

    stage('Docker Build & Deploy') {
      when {
        expression {
          currentBuild.resultIsBetterOrEqualTo('SUCCESS')
        }
      }
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"
          def containerName = "${IMAGE_NAME}_app"

          echo "🐳 Building Docker image: ${IMAGE_NAME}:${buildTag}"

          sh """
            docker build -t ${IMAGE_NAME}:${buildTag} .
            docker tag ${IMAGE_NAME}:${buildTag} ${DOCKERHUB_USER}/${IMAGE_NAME}:${buildTag}
            docker rm -f ${containerName} || true
            
          """

          sh 'git rev-parse HEAD > ${STABLE_FILE}'
        }
      }
    }

    // ✅ Push Docker Image to Docker Hub
          stage('Push Docker Image to Docker Hub') {
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"

          withCredentials([usernamePassword(
            credentialsId: "${DOCKER_HUB_CREDENTIALS_ID}",
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
          )]) {
            echo "📤 Pushing Docker image to Docker Hub as ${DOCKER_USER}/${IMAGE_NAME}:${buildTag}"

            sh """
              echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
              docker tag ${IMAGE_NAME}:${buildTag} $DOCKER_USER/${IMAGE_NAME}:${buildTag}
              docker push $DOCKER_USER/${IMAGE_NAME}:${buildTag}
              docker logout
            """
          }
        }
      }
    }



  }

  post {
    failure {
      script {
        echo "❌ Pipeline failed — starting rollback..."

        def failedFile = sh(
          script: "grep -Eo '/[^ ]+\\.(java|jsp|sql|prc|pck|tst)' ${env.WORKSPACE}/build.log | head -1 || true",
          returnStdout: true
        ).trim()

        if (failedFile) {
          echo "⚠️ Failed file detected: ${failedFile}"
          if (fileExists("${STABLE_FILE}")) {
            def lastCommit = readFile("${STABLE_FILE}").trim()
            echo "🔁 Rolling back ${failedFile} to ${lastCommit}"

            withCredentials([usernamePassword(credentialsId: "${GIT_CREDENTIALS_ID}", usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
              sh """
                git fetch origin main
                git checkout ${lastCommit} -- ${failedFile}
                git config user.name "Sougata1813"
                git config user.email "sougatapratihar50@gmail.com"
                git add ${failedFile}
                git commit -m "Rollback: ${failedFile} reverted to last stable commit after build failure"
                git push https://${GIT_USER}:${GIT_PASS}@github.com/Sougata1813/Hello.git HEAD:main
              """
            }
          } else {
            echo "⚠️ No stable commit file found — cannot rollback Git."
          }
        } else {
          echo "⚠️ Could not detect failed file — skipping Git rollback."
        }

        echo "🐳 Rolling back Docker container..."
        sh '''
          container_name="cicdpipeline_app"
          prev_image=$(docker images --format "{{.Repository}}:{{.Tag}}" cicdpipeline | sort -r | sed -n 2p)
          if [ -n "$prev_image" ]; then
            echo "Rolling back to previous Docker image: $prev_image"
            docker rm -f $container_name || true
            docker run -d --name $container_name -p 9090:8080 $prev_image
          else
            echo "⚠️ No previous image found for rollback."
          fi
        '''
      }
    }

    success {
      echo "✅ Build succeeded — new Docker image deployed and pushed to Docker Hub."
    }

    always {
      echo "🏁 Pipeline finished."
    }
  }
}
