#!/bin/bash

#############################################
# HNG13 Stage 1 - Automated Deployment Script
# Author: Chuye Princely Tata
#############################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file with timestamp
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

# Error handling trap
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

#############################################
# Step 1: Collect Parameters from User
#############################################

log "=========================================="
log "HNG13 Stage 1 - Deployment Script Started"
log "=========================================="

read -p "Enter Git Repository URL: " REPO_URL
read -sp "Enter Personal Access Token (PAT): " PAT
echo
read -p "Enter Branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -p "Enter Remote Server Username (default: ec2-user): " REMOTE_USER
REMOTE_USER=${REMOTE_USER:-ec2-user}

read -p "Enter Remote Server IP Address: " REMOTE_IP
read -p "Enter SSH Key Path (e.g., ~/stage1-remote-key.pem): " SSH_KEY
read -p "Enter Application Port (default: 3000): " APP_PORT
APP_PORT=${APP_PORT:-3000}

# Validate inputs
if [[ -z "$REPO_URL" || -z "$PAT" || -z "$REMOTE_IP" || -z "$SSH_KEY" ]]; then
    log_error "Required parameters missing!"
    exit 1
fi

# Validate SSH key exists
if [[ ! -f "$SSH_KEY" ]]; then
    log_error "SSH key not found at: $SSH_KEY"
    exit 1
fi

log "All parameters collected successfully"

#############################################
# Step 2: Clone the Repository
#############################################

log "Cloning repository from: $REPO_URL"

# Extract repo name from URL
REPO_NAME=$(basename "$REPO_URL" .git)
PROJECT_DIR="$HOME/$REPO_NAME"

# Add PAT to URL for authentication
AUTH_REPO_URL=$(echo "$REPO_URL" | sed "s|https://|https://$PAT@|")

if [[ -d "$PROJECT_DIR" ]]; then
    log_warning "Repository already exists. Pulling latest changes..."
    cd "$PROJECT_DIR" || exit 1
    git pull origin "$BRANCH" >> "$LOG_FILE" 2>&1
else
    git clone "$AUTH_REPO_URL" "$PROJECT_DIR" >> "$LOG_FILE" 2>&1
    cd "$PROJECT_DIR" || exit 1
fi

git checkout "$BRANCH" >> "$LOG_FILE" 2>&1
log "Repository cloned/updated successfully"

#############################################
# Step 3: Verify Dockerfile Exists
#############################################

log "Verifying Dockerfile..."

if [[ ! -f "Dockerfile" && ! -f "docker-compose.yml" ]]; then
    log_error "No Dockerfile or docker-compose.yml found!"
    exit 1
fi

log "Dockerfile found ✓"

#############################################
# Step 4: Test SSH Connection to Remote Server
#############################################

log "Testing SSH connection to $REMOTE_USER@$REMOTE_IP..."

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo 'SSH connection successful'" >> "$LOG_FILE" 2>&1

if [[ $? -ne 0 ]]; then
    log_error "Cannot connect to remote server!"
    exit 1
fi

log "SSH connection successful ✓"

#############################################
# Step 5: Prepare Remote Environment
#############################################

log "Preparing remote environment..."

ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" << 'REMOTE_SETUP'
    # Update system
    sudo yum update -y

    # Install Docker if not installed
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        sudo yum install docker -y
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    fi

    # Install Docker Compose if not installed
    if ! command -v docker-compose &> /dev/null; then
        echo "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi

    # Install Nginx if not installed
    if ! command -v nginx &> /dev/null; then
        echo "Installing Nginx..."
        sudo yum install nginx -y
        sudo systemctl start nginx
        sudo systemctl enable nginx
    fi

    # Verify installations
    echo "Docker version: $(docker --version)"
    echo "Docker Compose version: $(docker-compose --version)"
    echo "Nginx version: $(nginx -v 2>&1)"
REMOTE_SETUP

log "Remote environment prepared ✓"

#############################################
# Step 6: Deploy the Dockerized Application
#############################################

log "Transferring project files to remote server..."

# Create remote project directory
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" "mkdir -p ~/app"

# Transfer files using rsync or scp
rsync -avz -e "ssh -i $SSH_KEY" "$PROJECT_DIR/" "$REMOTE_USER@$REMOTE_IP:~/app/" >> "$LOG_FILE" 2>&1

if [[ $? -ne 0 ]]; then
    log_error "Failed to transfer files"
    exit 1
fi

log "Files transferred successfully ✓"

log "Building and deploying Docker container..."

ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" << REMOTE_DEPLOY
    cd ~/app

    # Stop and remove old containers
    docker stop ${REPO_NAME}-container 2>/dev/null || true
    docker rm ${REPO_NAME}-container 2>/dev/null || true

    # Build Docker image
    docker build -t ${REPO_NAME}-app:latest .

    # Run container
    docker run -d \
        --name ${REPO_NAME}-container \
        --restart unless-stopped \
        -p $APP_PORT:3000 \
        ${REPO_NAME}-app:latest

    # Wait for container to start
    sleep 5

    # Check container status
    docker ps | grep ${REPO_NAME}-container
REMOTE_DEPLOY

log "Docker container deployed ✓"

#############################################
# Step 7: Configure Nginx as Reverse Proxy
#############################################

log "Configuring Nginx reverse proxy..."

ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" << 'NGINX_CONFIG'
    # Create Nginx config
    sudo tee /etc/nginx/conf.d/app.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

    # Test Nginx configuration
    sudo nginx -t

    # Reload Nginx
    sudo systemctl reload nginx

    echo "Nginx configured successfully"
NGINX_CONFIG

log "Nginx reverse proxy configured ✓"

#############################################
# Step 8: Validate Deployment
#############################################

log "Validating deployment..."

# Test from remote server
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" << 'VALIDATE'
    # Check Docker service
    if ! systemctl is-active --quiet docker; then
        echo "ERROR: Docker is not running"
        exit 1
    fi

    # Check container health
    if ! docker ps | grep -q hng13-stage1-devops-container; then
        echo "ERROR: Container is not running"
        exit 1
    fi

    # Check Nginx
    if ! systemctl is-active --quiet nginx; then
        echo "ERROR: Nginx is not running"
        exit 1
    fi

    # Test application locally
    if ! curl -s http://localhost:3000 > /dev/null; then
        echo "ERROR: Application not responding on port 3000"
        exit 1
    fi

    # Test via Nginx
    if ! curl -s http://localhost > /dev/null; then
        echo "ERROR: Nginx proxy not working"
        exit 1
    fi

    echo "All validation checks passed"
VALIDATE

log "Deployment validation successful ✓"

#############################################
# Step 9: Final Tests
#############################################

log "Running final accessibility tests..."

# Test from local machine
curl -s "http://$REMOTE_IP" > /dev/null

if [[ $? -eq 0 ]]; then
    log "Application is accessible at: http://$REMOTE_IP"
else
    log_warning "Cannot access application from local machine. Check security groups."
fi

#############################################
# Deployment Summary
#############################################

log "=========================================="
log "Deployment Completed Successfully!"
log "=========================================="
log "Application URL: http://$REMOTE_IP"
log "Container Port: $APP_PORT"
log "Log file: $LOG_FILE"
log "=========================================="

# Display container logs
log "Recent container logs:"
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_IP" "docker logs --tail 20 ${REPO_NAME}-container"

exit 0
