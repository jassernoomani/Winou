# Jenkins for Winou, with everything the Jenkinsfile needs: JDK 25 (backend), Python (ML service),
# Flutter + Android command-line tools (app and APK), sonar-scanner, and the Docker CLI (to run
# Testcontainers and redeploy the stack through the host's Docker). See README.md here.
FROM jenkins/jenkins:2.580.2-lts-jdk21

ARG JDK_MAJOR=25
ARG FLUTTER_VERSION=3.47.6
ARG SONAR_SCANNER_VERSION=8.3.0.16463
ARG ANDROID_CMDLINE_TOOLS=13114758

USER root

# Docker CLI + compose plugin, Python with venv, and OpenCV's system libraries (ML service tests)
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg unzip xz-utils zip \
         python3 python3-venv libgl1 libglib2.0-0 \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
         > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# JDK 25 for the backend (Jenkins itself and Gradle keep the image's JDK 21)
RUN mkdir -p /opt/jdk-${JDK_MAJOR} \
    && curl -fsSL "https://api.adoptium.net/v3/binary/latest/${JDK_MAJOR}/ga/linux/x64/jdk/hotspot/normal/eclipse" \
         | tar -xz --strip-components=1 -C /opt/jdk-${JDK_MAJOR}

# sonar-scanner (ships its own JRE)
RUN curl -fsSL -o /tmp/scanner.zip \
         "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip" \
    && unzip -q /tmp/scanner.zip -d /opt \
    && mv /opt/sonar-scanner-* /opt/sonar-scanner \
    && rm /tmp/scanner.zip

# Android command-line tools. The SDK itself lives in the jenkins_home volume (ANDROID_HOME below),
# so platforms and build tools Gradle downloads survive image rebuilds.
RUN mkdir -p /opt/android-cmdline-tools \
    && curl -fsSL -o /tmp/tools.zip \
         "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" \
    && unzip -q /tmp/tools.zip -d /opt/android-cmdline-tools \
    && rm /tmp/tools.zip

# Flutter, same version as on the laptop
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter \
    && chown -R jenkins:jenkins /opt/flutter \
    && git config --system --add safe.directory '*'

ENV JDK25_HOME=/opt/jdk-${JDK_MAJOR} \
    ANDROID_HOME=/var/jenkins_home/android-sdk \
    PATH=/opt/flutter/bin:/opt/sonar-scanner/bin:/opt/android-cmdline-tools/cmdline-tools/bin:${PATH}

USER jenkins
RUN flutter config --no-analytics --no-cli-animations >/dev/null \
    && flutter precache --android --no-ios --no-web --no-linux --no-windows --no-macos --no-fuchsia

# Plugins and configuration as code (no setup wizard)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY casc/ /usr/share/jenkins/ref/casc/
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc/jenkins.yaml \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Xmx1g" \
    JENKINS_OPTS="--prefix=/jenkins"
