FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package -DskipTests

FROM eclipse-temurin:25-jre
RUN useradd --create-home appuser
WORKDIR /srv
COPY --from=build /src/target/winou-backend.jar app.jar
USER appuser

EXPOSE 8080
# bash's /dev/tcp: no curl in the image
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s CMD bash -c \
    'exec 3<>/dev/tcp/127.0.0.1/8080 && printf "GET /health HTTP/1.0\r\n\r\n" >&3 && grep -q "\"ok\"" <&3'
# Database migrations (Flyway) run at startup
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
