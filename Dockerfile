FROM eclipse-temurin:17-jre-alpine
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
# Set environment variable for Spring Boot server port
ENV SERVER_PORT=9090

# Expose port 9090 (optional, for documentation and mapping)
EXPOSE 9090

ENTRYPOINT ["java","-jar","/app.jar"]
