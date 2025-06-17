# Chainlit Data Layer Setup Guide

## Overview
This guide explains how to set up the Chainlit data layer on a separate EC2 instance and connect it to your main application.

## Prerequisites
1. Two EC2 instances:
   - Application instance (running Chainlit)
   - Data layer instance (running PostgreSQL and S3)
2. Security groups configured to allow communication between instances

## Security Group Configuration

### Data Layer Instance
Allow inbound traffic:
- Port 5432 (PostgreSQL) from Application instance
- Port 4566 (S3) from Application instance
- Port 22 (SSH) from your IP

### Application Instance
Allow inbound traffic:
- Port 80 (HTTP) from anywhere
- Port 443 (HTTPS) from anywhere
- Port 22 (SSH) from your IP

## Data Layer Setup

1. Connect to your data layer EC2 instance:
```bash
ssh -i your-key.pem ubuntu@datalayer-ec2-ip
```

2. Make the deployment script executable:
```bash
chmod +x deploy_datalayer.sh
```

3. Update the following in deploy_datalayer.sh:
   - Update the git repository URL
   - (Optional) Update SSL certificate details
   - (Optional) Update database credentials

4. Run the deployment script:
```bash
./deploy_datalayer.sh
```

5. Copy the SSL certificates to the application instance:
```bash
# On the data layer instance
sudo cp /opt/chainlit-datalayer/ssl/postgres.* /tmp/
sudo chmod 644 /tmp/postgres.*

# On your local machine
scp -i your-key.pem ubuntu@datalayer-ec2-ip:/tmp/postgres.* ./

# On the application instance
scp -i your-key.pem postgres.* ubuntu@app-ec2-ip:/var/www/litchain/ssl/
```

## Application Setup

1. Connect to your application EC2 instance:
```bash
ssh -i your-key.pem ubuntu@app-ec2-ip
```

2. Update the systemd service configuration:
```bash
sudo nano /etc/systemd/system/litchain.service
```

3. Replace `DATALAYER_IP` with your data layer instance's private IP address

4. Restart the application:
```bash
sudo systemctl daemon-reload
sudo systemctl restart litchain
```

## Verification

1. Check data layer services:
```bash
# On data layer instance
docker-compose ps
npx prisma studio
```

2. Check application logs:
```bash
# On application instance
sudo journalctl -u litchain -f
```

3. Test database connection:
```bash
# On application instance
psql "postgresql://root:root@DATALAYER_IP:5432/postgres?sslmode=require"
```

## Troubleshooting

### SSL Certificate Issues
1. Verify certificate permissions:
```bash
sudo ls -l /opt/chainlit-datalayer/ssl/
sudo ls -l /var/www/litchain/ssl/
```

2. Check PostgreSQL SSL configuration:
```bash
docker-compose logs postgres
```

### Connection Issues
1. Verify security groups:
```bash
# Test PostgreSQL connection
nc -zv DATALAYER_IP 5432

# Test S3 connection
nc -zv DATALAYER_IP 4566
```

2. Check application logs:
```bash
sudo journalctl -u litchain -f
```

## Backup and Maintenance

1. Backup database:
```bash
# On data layer instance
docker-compose exec postgres pg_dump -U root postgres > backup.sql
```

2. Backup SSL certificates:
```bash
sudo cp /opt/chainlit-datalayer/ssl/postgres.* /backup/ssl/
```

3. Monitor disk usage:
```bash
df -h
du -sh /opt/chainlit-datalayer/
```

## Security Considerations

1. Change default credentials:
   - Update PostgreSQL password
   - Update S3 access keys
   - Update application environment variables

2. Regular maintenance:
   - Update SSL certificates before expiration
   - Monitor logs for suspicious activity
   - Keep system and Docker images updated

3. Network security:
   - Use private IPs for internal communication
   - Restrict access to necessary ports only
   - Consider using AWS VPC for additional security 