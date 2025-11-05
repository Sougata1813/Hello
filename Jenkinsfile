pipeline {
  agent any

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }

  environment {
    IMAGE_NAME = "cicdpipeline"
    STABLE_FILE = "last_stable_commit.txt"
    GIT_CREDENTIALS_ID = "github-token"
    DOCKER_HUB_CREDENTIALS_ID = "docker-token"
    DOCKERHUB_USER = "sougata18"

    // --- AWS Configuration ---
    AWS_CREDENTIALS_ID = "aws-creds"
    AWS_REGION = "us-east-1"
    AWS_ACCOUNT_ID = "654654627536"
    ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}"
    ECS_CLUSTER = "mycicdpipeline"
    ECS_SERVICE = "cicdpipeline_family_service_1"
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
              mvn clean test package spring-boot:repackage -DskipTests=false 2>&1 | tee build.log
            '''
            def jarStatus = sh(script: 'ls -1 target/*.jar 2>/dev/null | wc -l', returnStdout: true).trim()
            if (jarStatus == '0') {
              error("❌ Maven build did not produce a JAR file.")
            }
          } catch (err) {
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

    stage('Docker Build') {
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
              docker push $DOCKER_USER/${IMAGE_NAME}:${buildTag}
              docker logout
            """
          }
        }
      }
    }

    stage('Push Docker Image to AWS ECR') {
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"
          echo "📦 Pushing Docker image to AWS ECR..."
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
            sh """
              aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}
              docker tag ${DOCKERHUB_USER}/${IMAGE_NAME}:${buildTag} ${ECR_REPO}:${buildTag}
              docker push ${ECR_REPO}:${buildTag}
            """
          }
        }
      }
    }

    // ✅ FIXED DEPLOYMENT STAGE
    stage('Deploy to AWS ECS') {
      steps {
        script {
          def buildTag = "v${env.BUILD_NUMBER}"
          echo "🚀 Deploying image ${ECR_REPO}:${buildTag} to ECS..."

          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
            sh """
              set -e
              CLUSTER=${ECS_CLUSTER}
              SERVICE=${ECS_SERVICE}
              IMAGE=${ECR_REPO}:${buildTag}

              echo "📦 Fetching current task definition..."
              TASK_DEF_ARN=\$(aws ecs describe-services --cluster \$CLUSTER --services \$SERVICE --query "services[0].taskDefinition" --output text)

              echo "🧾 Describing task definition: \$TASK_DEF_ARN"
              aws ecs describe-task-definition --task-definition \$TASK_DEF_ARN --query "taskDefinition" > task-def.json

              echo "🛠️ Updating container image in task definition..."
              cat task-def.json | jq --arg IMAGE "\$IMAGE" '
                .containerDefinitions[0].image = \$IMAGE
                | del(
                    .status,
                    .revision,
                    .taskDefinitionArn,
                    .requiresAttributes,
                    .compatibilities,
                    .registeredAt,
                    .registeredBy,
                    .deregisteredAt
                  )
              ' > new-task-def.json

              echo "📋 Registering new task definition..."
              NEW_TASK_DEF_ARN=\$(aws ecs register-task-definition --cli-input-json file://new-task-def.json --query "taskDefinition.taskDefinitionArn" --output text)

              echo "🔄 Updating ECS service to use new task definition..."
              aws ecs update-service --cluster \$CLUSTER --service \$SERVICE --task-definition \$NEW_TASK_DEF_ARN

              echo "✅ ECS service updated successfully to task definition: \$NEW_TASK_DEF_ARN"
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
        }
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
      echo "✅ Build succeeded — image deployed to ECS & pushed to both Docker Hub and ECR."
    }

    always {
      echo "🏁 Pipeline finished."
    }
  }
}
