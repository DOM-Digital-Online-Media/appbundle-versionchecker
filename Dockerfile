FROM --platform=linux/amd64 python:3.10-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    default-jre unzip curl bash apktool \
    && rm -rf /var/lib/apt/lists/*

# Copy everything into the container
COPY . .

# Download bundletool
RUN curl -L -o bundletool.jar https://github.com/google/bundletool/releases/download/1.15.6/bundletool-all-1.15.6.jar

RUN chmod +x parse_aab.sh parse_xcarchive.sh

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

CMD ["python", "app.py"]
