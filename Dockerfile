FROM --platform=linux/amd64 python:3.10-slim

WORKDIR /app

# Install dependencies including 'file' and glibc for aapt2
RUN apt-get update && apt-get install -y \
  default-jre unzip curl bash apktool file libc6 libstdc++6 qemu-user qemu-user-static \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /lib64 /usr/lib64 && \
  ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2 && \
  ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /usr/lib64/ld-linux-x86-64.so.2

# Install Android Command Line Tools
RUN mkdir -p /opt/android-sdk && \
  cd /opt/android-sdk && \
  curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
  unzip cmdline-tools.zip -d cmdline-tools && \
  rm cmdline-tools.zip && \
  yes | cmdline-tools/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk --install "build-tools;34.0.0"

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="/opt/android-sdk/build-tools/34.0.0:$PATH"
ENV LD_LIBRARY_PATH=/usr/lib64:/lib/x86_64-linux-gnu:/lib64:/lib

COPY . .

RUN curl -L -o bundletool.jar https://github.com/google/bundletool/releases/download/1.15.6/bundletool-all-1.15.6.jar

RUN chmod +x parse_aab.sh parse_xcarchive.sh

RUN pip install --no-cache-dir -r requirements.txt

RUN apt-get update && apt-get install -y binfmt-support && \
  update-binfmts --display | grep -q qemu-x86_64 || \
  echo ':qemu-x86_64:M::\x7fELF\x02\x01\x01:\xff\xff\xff\xff\xff\xff\xff\x00:/usr/bin/qemu-x86_64:' > /etc/binfmt.d/qemu-x86_64.conf

EXPOSE 8080

# Ensure environment is active for Java and aapt2
CMD /bin/bash -c 'export ANDROID_SDK_ROOT=/opt/android-sdk && export LD_LIBRARY_PATH=/lib64:/lib/x86_64-linux-gnu && export PATH="/opt/android-sdk/build-tools/34.0.0:$PATH" && python app.py'