FROM eclipse-temurin:17.0.20_8-jdk-ubi10-minimal AS build

WORKDIR /workspace

COPY . .

ARG SERVICE
RUN test -n "$SERVICE" \
    && chmod +x gradlew \
    && ./gradlew :${SERVICE}:bootJar --no-daemon

FROM eclipse-temurin:17.0.20_8-jre-ubi10-minimal

WORKDIR /app

ARG SERVICE
COPY --from=build --chown=1001:0 /workspace/${SERVICE}/build/libs/*.jar app.jar

USER 1001

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
