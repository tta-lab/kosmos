# Build the server from the archived ClipCascade checkout.  The upstream
# Dockerfile expects a pre-built target/*.jar, so the build stage is owned by
# Kosmos and never relies on an untracked target directory in the checkout.
FROM docker.io/library/maven:3.9.9-eclipse-temurin-21@sha256:3a4ab3276a087bf276f79cae96b1af04f53731bec53fb2e651aca79e4b10211e AS build

WORKDIR /src/ClipCascade_Server/ClipCascade_Backend
COPY ClipCascade_Server/ClipCascade_Backend/pom.xml .

COPY ClipCascade_Server/ClipCascade_Backend/src src
RUN mvn --batch-mode --no-transfer-progress -DskipTests package

FROM docker.io/library/eclipse-temurin:21-jre-jammy@sha256:eebd356ad7358b7094758e5787a6726f332917cfd56feab6457c56dab895cdbf

ARG APP_UID=10001
ARG APP_GID=10001

RUN groupadd --gid "${APP_GID}" clipcascade \
  && useradd --uid "${APP_UID}" --gid "${APP_GID}" --create-home --home-dir /home/clipcascade --shell /usr/sbin/nologin clipcascade \
  && mkdir -p /app/logs /database \
  && chown -R "${APP_UID}:${APP_GID}" /app /database /home/clipcascade

WORKDIR /app
COPY --from=build /src/ClipCascade_Server/ClipCascade_Backend/target/*.jar /app/app.jar
RUN chown "${APP_UID}:${APP_GID}" /app/app.jar

USER ${APP_UID}:${APP_GID}
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
