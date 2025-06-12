FROM --platform=linux/amd64 python:3.10-slim

WORKDIR /app

# Install only essential dependencies and clean up in the same layer
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  default-jre unzip curl bash \
  && rm -rf /var/lib/apt/lists/*

# Setup symlinks for glibc loader needed by aapt2
RUN mkdir -p /lib64 /usr/lib64 && \
  ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2 && \
  ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /usr/lib64/ld-linux-x86-64.so.2

# Install Android Command Line Tools and build-tools, then remove cmdline-tools to slim image
RUN mkdir -p /opt/android-sdk && \
  cd /opt/android-sdk && \
  curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
  unzip cmdline-tools.zip -d cmdline-tools && \
  rm cmdline-tools.zip && \
  yes | cmdline-tools/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk --install "build-tools;34.0.0" && \
  rm -rf /opt/android-sdk/cmdline-tools

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="/opt/android-sdk/build-tools/34.0.0:$PATH"
ENV LD_LIBRARY_PATH=/usr/lib64:/lib/x86_64-linux-gnu:/lib64:/lib

COPY . .

RUN curl -L -o bundletool.jar https://github.com/google/bundletool/releases/download/1.15.6/bundletool-all-1.15.6.jar

RUN chmod +x parse_aab.sh parse_xcarchive.sh

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

# Ensure environment is active for Java and aapt2
CMD /bin/bash -c 'export ANDROID_SDK_ROOT=/opt/android-sdk && export LD_LIBRARY_PATH=/lib64:/lib/x86_64-linux-gnu && export PATH="/opt/android-sdk/build-tools/34.0.0:$PATH" && python app.py'