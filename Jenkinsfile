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

        AWS_CREDENTIALS_ID = "aws-creds"
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT_ID = "654654627536"
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}"
        ECS_CLUSTER = "mycicdpipeline_1"
        ECS_SERVICE = "cicdpipeline_family_service_2"
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
                    sh 'mvn clean test package spring-boot:repackage -DskipTests=false 2>&1 | tee build.log'
                    def jarStatus = sh(script: 'ls -1 target/*.jar 2>/dev/null | wc -l', returnStdout: true).trim()
                    if (jarStatus == '0') {
                        error("❌ Maven build did not produce a JAR file.")
                    }
                }
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    echo "🐳 Building Docker image..."
                    def buildTag = "v${env.BUILD_NUMBER}"
                    sh """
                        docker build -t ${IMAGE_NAME}:${buildTag} .
                        git rev-parse HEAD > ${STABLE_FILE}
                    """
                }
            }
        }

        stage('Docker Push to Docker Hub') {
            steps {
                script {
                    def buildTag = "v${env.BUILD_NUMBER}"
                    withCredentials([usernamePassword(
                        credentialsId: "${DOCKER_HUB_CREDENTIALS_ID}",
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                            docker tag ${IMAGE_NAME}:${buildTag} ${DOCKERHUB_USER}/${IMAGE_NAME}:${buildTag}
                            docker push ${DOCKERHUB_USER}/${IMAGE_NAME}:${buildTag}
                            docker logout
                        """
                    }
                }
            }
        }

        stage('Optional: Docker Run Locally') {
            steps {
                script {
                    def buildTag = "v${env.BUILD_NUMBER}"
                    echo "⚡ Running container locally for test..."
                    sh """
                        docker rm -f ${IMAGE_NAME}_app || true
                        docker run -d --name ${IMAGE_NAME}_app ${DOCKERHUB_USER}/${IMAGE_NAME}:${buildTag}
                    """
                }
            }
        }

        stage('Push Docker Image to AWS ECR') {
            steps {
                script {
                    def buildTag = "v${env.BUILD_NUMBER}"
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

        stage('Deploy Latest ECR Image to ECS') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        sh """
                            set -e
                            CLUSTER=${ECS_CLUSTER}
                            SERVICE=${ECS_SERVICE}
                            REPO=${ECR_REPO}
                            AWS_REGION=${AWS_REGION}

                            echo "📦 Fetching latest image tag from ECR..."
                            LATEST_TAG=\$(aws ecr describe-images --repository-name ${IMAGE_NAME} \
                                --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]' \
                                --output text --region \$AWS_REGION)

                            IMAGE_URI=\${REPO}:\$LATEST_TAG
                            echo "✅ Latest image URI: \$IMAGE_URI"

                            # Fetch current ECS task definition
                            TASK_DEF_ARN=\$(aws ecs describe-services --cluster \$CLUSTER --services \$SERVICE \
                                --query "services[0].taskDefinition" --output text)

                            # Update task definition JSON
                            aws ecs describe-task-definition --task-definition \$TASK_DEF_ARN \
                                --query "taskDefinition" > task-def.json

                            cat task-def.json | jq --arg IMAGE "\$IMAGE_URI" '
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

                            # Register new task definition
                            NEW_TASK_DEF_ARN=\$(aws ecs register-task-definition --cli-input-json file://new-task-def.json \
                                --query "taskDefinition.taskDefinitionArn" --output text)

                            # Update ECS service
                            aws ecs update-service --cluster \$CLUSTER --service \$SERVICE --task-definition \$NEW_TASK_DEF_ARN

                            echo "✅ ECS service updated successfully to latest image: \$IMAGE_URI"
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
            }
        }

        success {
            echo "✅ Build succeeded — image deployed to ECS & pushed to Docker Hub/ECR."
        }

        always {
            echo "🏁 Pipeline finished."
        }
    }
}
