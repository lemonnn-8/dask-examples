# Physiotherapy Management System - Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the physiotherapy management system across different environments (development, staging, and production) using various cloud providers and deployment strategies.

## Prerequisites

### System Requirements
- **Node.js**: 18.x or higher
- **PostgreSQL**: 15.x or higher
- **Redis**: 7.x or higher
- **Docker**: 20.x or higher (optional but recommended)
- **Git**: Latest version

### Cloud Services
- **AWS Account** (recommended) or **Google Cloud Platform** or **DigitalOcean**
- **Domain name** for production deployment
- **SSL Certificate** (Let's Encrypt recommended)
- **CDN Service** (CloudFlare recommended)

## Environment Setup

### 1. Development Environment

#### Local Setup with Docker Compose

Create `docker-compose.yml`:
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: physio_dev
      POSTGRES_USER: physio_user
      POSTGRES_PASSWORD: physio_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database-schema.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  api:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://physio_user:physio_password@postgres:5432/physio_dev
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=your-jwt-secret-key
      - STRIPE_SECRET_KEY=sk_test_your_stripe_key
      - AWS_ACCESS_KEY_ID=your-aws-key
      - AWS_SECRET_ACCESS_KEY=your-aws-secret
      - S3_BUCKET_NAME=physio-dev-uploads
    depends_on:
      - postgres
      - redis
    volumes:
      - ./backend:/app
      - /app/node_modules

  web:
    build: ./frontend
    ports:
      - "3001:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:3000/api
      - REACT_APP_STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_key
    volumes:
      - ./frontend:/app
      - /app/node_modules

volumes:
  postgres_data:
  redis_data:
```

#### Start Development Environment
```bash
# Clone the repository
git clone https://github.com/your-org/physio-management-system.git
cd physio-management-system

# Start services
docker-compose up -d

# Install dependencies (if not using Docker)
cd backend && npm install
cd ../frontend && npm install

# Run migrations
npm run migrate

# Seed development data
npm run seed:dev
```

### 2. Production Environment Setup

## AWS Deployment (Recommended)

### Infrastructure Setup with Terraform

Create `infrastructure/main.tf`:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "physio-vpc"
  }
}

# Subnets
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "physio-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "physio-private-subnet-${count.index + 1}"
  }
}

# RDS Instance
resource "aws_db_instance" "postgres" {
  identifier     = "physio-postgres"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = "physio_prod"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = false
  final_snapshot_identifier = "physio-postgres-final-snapshot"

  tags = {
    Name = "physio-postgres"
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "main" {
  name       = "physio-cache-subnet"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "physio-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "physio-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "physio-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "physio-alb"
  }
}

# S3 Bucket for file uploads
resource "aws_s3_bucket" "uploads" {
  bucket = "physio-uploads-${random_string.bucket_suffix.result}"
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "physio-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "physio-alb"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

### ECS Task Definitions

Create `infrastructure/ecs-tasks.tf`:
```hcl
# Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "physio-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "${aws_ecr_repository.backend.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = "3000"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_ssm_parameter.database_url.arn
        },
        {
          name      = "REDIS_URL"
          valueFrom = aws_ssm_parameter.redis_url.arn
        },
        {
          name      = "JWT_SECRET"
          valueFrom = aws_ssm_parameter.jwt_secret.arn
        },
        {
          name      = "STRIPE_SECRET_KEY"
          valueFrom = aws_ssm_parameter.stripe_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# Frontend Task Definition
resource "aws_ecs_task_definition" "frontend" {
  family                   = "physio-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = "${aws_ecr_repository.frontend.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.frontend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}
```

### Deployment Scripts

Create `scripts/deploy.sh`:
```bash
#!/bin/bash

set -e

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="physio-cluster"
BACKEND_SERVICE="physio-backend"
FRONTEND_SERVICE="physio-frontend"
BACKEND_REPO="physio-backend"
FRONTEND_REPO="physio-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        echo_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        echo_error "Terraform is not installed"
        exit 1
    fi
    
    echo_info "Prerequisites check passed"
}

# Build and push Docker images
build_and_push() {
    echo_info "Building and pushing Docker images..."
    
    # Get ECR login token
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com
    
    # Build and push backend
    echo_info "Building backend image..."
    cd backend
    docker build -t $BACKEND_REPO .
    docker tag $BACKEND_REPO:latest $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$BACKEND_REPO:latest
    docker push $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$BACKEND_REPO:latest
    cd ..
    
    # Build and push frontend
    echo_info "Building frontend image..."
    cd frontend
    docker build -t $FRONTEND_REPO .
    docker tag $FRONTEND_REPO:latest $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$FRONTEND_REPO:latest
    docker push $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$FRONTEND_REPO:latest
    cd ..
    
    echo_info "Images pushed successfully"
}

# Deploy infrastructure
deploy_infrastructure() {
    echo_info "Deploying infrastructure with Terraform..."
    
    cd infrastructure
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan
    cd ..
    
    echo_info "Infrastructure deployed successfully"
}

# Update ECS services
update_services() {
    echo_info "Updating ECS services..."
    
    # Update backend service
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $BACKEND_SERVICE \
        --force-new-deployment \
        --region $AWS_REGION
    
    # Update frontend service
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $FRONTEND_SERVICE \
        --force-new-deployment \
        --region $AWS_REGION
    
    echo_info "Services updated successfully"
}

# Wait for deployment to complete
wait_for_deployment() {
    echo_info "Waiting for deployment to complete..."
    
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $BACKEND_SERVICE $FRONTEND_SERVICE \
        --region $AWS_REGION
    
    echo_info "Deployment completed successfully"
}

# Run database migrations
run_migrations() {
    echo_info "Running database migrations..."
    
    # Get the task definition ARN
    TASK_DEF_ARN=$(aws ecs describe-task-definition --task-definition physio-backend --query 'taskDefinition.taskDefinitionArn' --output text)
    
    # Run migration task
    aws ecs run-task \
        --cluster $CLUSTER_NAME \
        --task-definition $TASK_DEF_ARN \
        --overrides '{
            "containerOverrides": [
                {
                    "name": "backend",
                    "command": ["npm", "run", "migrate"]
                }
            ]
        }' \
        --network-configuration '{
            "awsvpcConfiguration": {
                "subnets": ["subnet-xxx", "subnet-yyy"],
                "securityGroups": ["sg-xxx"],
                "assignPublicIp": "ENABLED"
            }
        }' \
        --region $AWS_REGION
    
    echo_info "Migrations completed"
}

# Main deployment function
main() {
    echo_info "Starting deployment process..."
    
    check_prerequisites
    build_and_push
    deploy_infrastructure
    update_services
    wait_for_deployment
    run_migrations
    
    echo_info "Deployment completed successfully!"
    echo_info "Application is available at: https://$(aws cloudfront list-distributions --query 'DistributionList.Items[0].DomainName' --output text)"
}

# Run main function
main "$@"
```

### Docker Configuration

#### Backend Dockerfile
Create `backend/Dockerfile`:
```dockerfile
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership of the app directory
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["npm", "start"]
```

#### Frontend Dockerfile
Create `frontend/Dockerfile`:
```dockerfile
# Build stage
FROM node:18-alpine as build

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built app
COPY --from=build /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

#### Nginx Configuration
Create `frontend/nginx.conf`:
```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # Handle client-side routing
        location / {
            try_files $uri $uri/ /index.html;
        }

        # API proxy
        location /api {
            proxy_pass http://backend:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # Static assets caching
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

## Environment Variables

### Production Environment Variables
Create `.env.production`:
```bash
# Application
NODE_ENV=production
PORT=3000
API_URL=https://api.yourdomain.com

# Database
DATABASE_URL=postgresql://username:password@your-rds-endpoint:5432/physio_prod
REDIS_URL=redis://your-elasticache-endpoint:6379

# Authentication
JWT_SECRET=your-super-secure-jwt-secret-key
JWT_EXPIRES_IN=24h
REFRESH_TOKEN_EXPIRES_IN=7d

# AWS Services
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
S3_BUCKET_NAME=your-s3-bucket-name
CLOUDFRONT_DOMAIN=your-cloudfront-domain

# Payment Processing
STRIPE_SECRET_KEY=sk_live_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Email Service
SENDGRID_API_KEY=your-sendgrid-api-key
FROM_EMAIL=noreply@yourdomain.com

# Push Notifications
FCM_SERVER_KEY=your-fcm-server-key

# Monitoring
SENTRY_DSN=your-sentry-dsn
NEW_RELIC_LICENSE_KEY=your-newrelic-license-key

# Security
CORS_ORIGIN=https://yourdomain.com
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# File Upload
MAX_FILE_SIZE=500MB
ALLOWED_FILE_TYPES=mp4,mov,avi,wmv,jpg,jpeg,png,pdf

# Business Settings
DEFAULT_TIMEZONE=America/New_York
DEFAULT_CURRENCY=USD
TAX_RATE=0.0875
```

## CI/CD Pipeline

### GitHub Actions Workflow
Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY_BACKEND: physio-backend
  ECR_REPOSITORY_FRONTEND: physio-frontend
  ECS_CLUSTER: physio-cluster
  ECS_SERVICE_BACKEND: physio-backend
  ECS_SERVICE_FRONTEND: physio-frontend

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: physio_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: |
          backend/package-lock.json
          frontend/package-lock.json
    
    - name: Install backend dependencies
      run: |
        cd backend
        npm ci
    
    - name: Install frontend dependencies
      run: |
        cd frontend
        npm ci
    
    - name: Run backend tests
      run: |
        cd backend
        npm run test
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/physio_test
        REDIS_URL: redis://localhost:6379
        JWT_SECRET: test-secret
    
    - name: Run frontend tests
      run: |
        cd frontend
        npm run test -- --coverage --watchAll=false
    
    - name: Run E2E tests
      run: |
        cd backend
        npm start &
        cd ../frontend
        npm start &
        sleep 30
        npm run test:e2e

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build and push backend image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        IMAGE_TAG: ${{ github.sha }}
      run: |
        cd backend
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$IMAGE_TAG
        docker tag $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:latest
        docker push $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:latest
    
    - name: Build and push frontend image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        IMAGE_TAG: ${{ github.sha }}
      run: |
        cd frontend
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY_FRONTEND:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY_FRONTEND:$IMAGE_TAG
        docker tag $ECR_REGISTRY/$ECR_REPOSITORY_FRONTEND:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY_FRONTEND:latest
        docker push $ECR_REGISTRY/$ECR_REPOSITORY_FRONTEND:latest
    
    - name: Deploy to ECS
      run: |
        aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE_BACKEND --force-new-deployment
        aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE_FRONTEND --force-new-deployment
    
    - name: Wait for deployment
      run: |
        aws ecs wait services-stable --cluster $ECS_CLUSTER --services $ECS_SERVICE_BACKEND $ECS_SERVICE_FRONTEND
    
    - name: Run database migrations
      run: |
        # Run migrations using ECS task
        aws ecs run-task \
          --cluster $ECS_CLUSTER \
          --task-definition physio-backend \
          --overrides '{
            "containerOverrides": [
              {
                "name": "backend",
                "command": ["npm", "run", "migrate"]
              }
            ]
          }'
```

## Monitoring and Logging

### CloudWatch Configuration
```yaml
# cloudwatch-config.yml
Resources:
  LogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /ecs/physio-management
      RetentionInDays: 30

  MetricFilter:
    Type: AWS::Logs::MetricFilter
    Properties:
      LogGroupName: !Ref LogGroup
      FilterPattern: "[timestamp, request_id, level=\"ERROR\", ...]"
      MetricTransformations:
        - MetricNamespace: PhysioManagement
          MetricName: ErrorCount
          MetricValue: "1"

  ErrorAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: PhysioManagement-ErrorRate
      AlarmDescription: High error rate detected
      MetricName: ErrorCount
      Namespace: PhysioManagement
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 10
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref SNSTopicArn
```

### Health Checks
Create `backend/routes/health.js`:
```javascript
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const redis = require('redis');

router.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    services: {}
  };

  try {
    // Check database connection
    const pool = new Pool({ connectionString: process.env.DATABASE_URL });
    await pool.query('SELECT 1');
    health.services.database = 'ok';
    await pool.end();
  } catch (error) {
    health.services.database = 'error';
    health.status = 'error';
  }

  try {
    // Check Redis connection
    const client = redis.createClient({ url: process.env.REDIS_URL });
    await client.connect();
    await client.ping();
    health.services.redis = 'ok';
    await client.quit();
  } catch (error) {
    health.services.redis = 'error';
    health.status = 'error';
  }

  const statusCode = health.status === 'ok' ? 200 : 503;
  res.status(statusCode).json(health);
});

module.exports = router;
```

## Security Configuration

### SSL/TLS Setup
```bash
# Install Certbot for Let's Encrypt
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Auto-renewal cron job
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### Security Headers
```nginx
# Add to nginx configuration
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://js.stripe.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self' https://api.stripe.com;" always;
```

## Backup and Recovery

### Database Backup Script
Create `scripts/backup.sh`:
```bash
#!/bin/bash

# Configuration
DB_HOST="your-rds-endpoint"
DB_NAME="physio_prod"
DB_USER="your-username"
BACKUP_DIR="/backups"
S3_BUCKET="physio-backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > $BACKUP_DIR/physio_backup_$DATE.sql

# Compress backup
gzip $BACKUP_DIR/physio_backup_$DATE.sql

# Upload to S3
aws s3 cp $BACKUP_DIR/physio_backup_$DATE.sql.gz s3://$S3_BUCKET/

# Clean up local backups older than 7 days
find $BACKUP_DIR -name "physio_backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: physio_backup_$DATE.sql.gz"
```

### Recovery Procedure
```bash
#!/bin/bash

# Download backup from S3
aws s3 cp s3://physio-backups/physio_backup_YYYYMMDD_HHMMSS.sql.gz ./

# Decompress
gunzip physio_backup_YYYYMMDD_HHMMSS.sql.gz

# Restore database
psql -h $DB_HOST -U $DB_USER -d $DB_NAME < physio_backup_YYYYMMDD_HHMMSS.sql
```

## Performance Optimization

### CDN Configuration
```javascript
// CloudFront cache behaviors
const cacheBehaviors = [
  {
    pathPattern: '/api/*',
    cachePolicyId: '4135ea2d-6df8-44a3-9df3-4b5a84be39ad', // CachingDisabled
    originRequestPolicyId: '88a5eaf4-2fd4-4709-b370-b4c650ea3fcf', // CORS-S3Origin
  },
  {
    pathPattern: '/static/*',
    cachePolicyId: '658327ea-f89d-4fab-a63d-7e88639e58f6', // CachingOptimized
    compress: true,
  },
  {
    pathPattern: '/videos/*',
    cachePolicyId: '4135ea2d-6df8-44a3-9df3-4b5a84be39ad', // CachingDisabled (for authenticated content)
  }
];
```

### Database Optimization
```sql
-- Create indexes for performance
CREATE INDEX CONCURRENTLY idx_appointments_date_therapist ON appointments(appointment_date, physiotherapist_id);
CREATE INDEX CONCURRENTLY idx_sessions_patient_date ON sessions(patient_id, session_date DESC);
CREATE INDEX CONCURRENTLY idx_invoices_patient_status ON invoices(patient_id, status);
CREATE INDEX CONCURRENTLY idx_videos_patient_type ON videos(patient_id, video_type);

-- Analyze tables for query optimization
ANALYZE appointments;
ANALYZE sessions;
ANALYZE invoices;
ANALYZE videos;
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Issues
```bash
# Check RDS connectivity
telnet your-rds-endpoint 5432

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Test database connection
psql -h your-rds-endpoint -U username -d physio_prod
```

#### 2. ECS Service Issues
```bash
# Check service status
aws ecs describe-services --cluster physio-cluster --services physio-backend

# Check task logs
aws logs get-log-events --log-group-name /ecs/physio-backend --log-stream-name ecs/backend/task-id

# Force new deployment
aws ecs update-service --cluster physio-cluster --service physio-backend --force-new-deployment
```

#### 3. Load Balancer Issues
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# Check ALB logs
aws s3 ls s3://your-alb-logs-bucket/
```

### Rollback Procedure
```bash
#!/bin/bash

# Rollback to previous task definition
PREVIOUS_TASK_DEF=$(aws ecs list-task-definitions --family-prefix physio-backend --status ACTIVE --sort DESC --max-items 2 --query 'taskDefinitionArns[1]' --output text)

aws ecs update-service \
  --cluster physio-cluster \
  --service physio-backend \
  --task-definition $PREVIOUS_TASK_DEF

# Wait for rollback to complete
aws ecs wait services-stable --cluster physio-cluster --services physio-backend
```

This comprehensive deployment guide provides everything needed to deploy the physiotherapy management system from development to production, including infrastructure setup, CI/CD pipelines, monitoring, security, and troubleshooting procedures.