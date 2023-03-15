# docker build --build-arg --no-cache -t "hello-service" -f "./src/main/docker/Dockerfile" .
# docker tag hello-service acrhello42.azurecr.io/hello/hello-service
# docker push acrhello42.azurecr.io/hello/hello-service
# docker pull acrhello42.azurecr.io/hello/hello-service
# docker image ls | grep -i hello
# docker run -p 8080:8080 -p 8081:8081 hello-service
# docker run --env SPRING_PROFILES_ACTIVE=toto -p 8080:8080 -p 8081:8081 hello-service
# docker container ls
# docker ps
# docker exec -it <container-id> /bin/sh

# https://docs.microsoft.com/en-us/java/openjdk/containers
FROM mcr.microsoft.com/openjdk/jdk:17-mariner as builder
ENV APPI_VERSION="3.4.10"
ENV APPLICATIONINSIGHTS_CONFIGURATION_FILE="BOOT-INF/classes/applicationinsights.json"
ENV SPRING_PROFILES_ACTIVE="docker"
LABEL Maintainer="pinpin <noname@microsoft.com>"
LABEL Description="Hello service: Java Spring Boot microservice built from MS OpenJDK 17-Mariner"
RUN mkdir /tmp/app
WORKDIR /tmp/app
COPY "./target/hellospring-0.0.1-SNAPSHOT.jar" /tmp/app/app.jar
#RUN java -Djarmode=layertools -jar "/tmp/app/app.jar" extract
RUN ls  /tmp/app
EXPOSE 80 8080 8081
ENTRYPOINT ["java", "-jar", "/tmp/app/app.jar", "--server.port=8080"]