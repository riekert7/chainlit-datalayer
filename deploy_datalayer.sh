#!/bin/bash

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker and Docker Compose
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-compose

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Create application directory
sudo mkdir -p /opt/chainlit-datalayer
sudo chown ubuntu:ubuntu /opt/chainlit-datalayer

# Clone repository
git clone https://github.com/your-repo/chainlit-datalayer.git /opt/chainlit-datalayer

# Generate self-signed SSL certificate for PostgreSQL
sudo mkdir -p /opt/chainlit-datalayer/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/chainlit-datalayer/ssl/postgres.key \
    -out /opt/chainlit-datalayer/ssl/postgres.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Set proper permissions for SSL certificates
sudo chown -R 999:999 /opt/chainlit-datalayer/ssl

# Create .env file
cat > /opt/chainlit-datalayer/.env << EOF
# Database configuration
POSTGRES_USER=root
POSTGRES_PASSWORD=root
POSTGRES_DB=postgres
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

# S3 configuration (for local development)
BUCKET_NAME=my-bucket
APP_AWS_ACCESS_KEY=random-key
APP_AWS_SECRET_KEY=random-key
APP_AWS_REGION=eu-central-1
DEV_AWS_ENDPOINT=http://localhost:4566

# SSL Configuration
POSTGRES_SSL_MODE=require
POSTGRES_SSL_CERT=/etc/ssl/postgres.crt
POSTGRES_SSL_KEY=/etc/ssl/postgres.key
EOF

# Create docker-compose.yml
cat > /opt/chainlit-datalayer/docker-compose.yml << EOF
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: root
      POSTGRES_PASSWORD: root
      POSTGRES_DB: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./ssl:/etc/ssl
    command: >
      postgres
      -c ssl=on
      -c ssl_cert_file=/etc/ssl/postgres.crt
      -c ssl_key_file=/etc/ssl/postgres.key
      -c ssl_ca_file=/etc/ssl/postgres.crt
    restart: always

  s3:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - s3_data:/tmp/localstack/data
    restart: always

volumes:
  postgres_data:
  s3_data:
EOF

# Start services
cd /opt/chainlit-datalayer
docker-compose up -d

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 10

# Run Prisma migrations
cd /opt/chainlit-datalayer
npx prisma migrate deploy

# Create systemd service for automatic startup
sudo tee /etc/systemd/system/chainlit-datalayer.service << EOF
[Unit]
Description=Chainlit Data Layer
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/chainlit-datalayer
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable chainlit-datalayer
sudo systemctl start chainlit-datalayer 