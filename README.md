# HNG13 Stage 1 - Automated Deployment Script

## Author
- Name: Chuye Princely Tata
- Slack Username: @PrincelyT

## Project Description
This project contains a production-grade Bash script that automates the deployment of a Dockerized Node.js application to a remote Linux server with Nginx reverse proxy.

## Features
- Automated repository cloning with PAT authentication
- Remote server environment setup (Docker, Docker Compose, Nginx)
- Dockerized application deployment
- Nginx reverse proxy configuration
- Comprehensive error handling and logging
- Deployment validation and health checks
- Idempotent execution (safe to re-run)

## Prerequisites
- Two Linux servers (local and remote)
- SSH access between servers
- GitHub repository with Dockerfile
- GitHub Personal Access Token

## Usage

1. Clone this repository
2. Make the script executable: `chmod +x deploy.sh`
3. Run the script: `./deploy.sh`
4. Follow the prompts to enter:
   - Git repository URL
   - Personal Access Token
   - Branch name
   - Remote server details
   - Application port

## Application Details
- **Framework**: Node.js with Express
- **Container Port**: 3000
- **Public Port**: 80 (via Nginx)
- **Deployment URL**: http://13.60.218.192

## Script Components

### 1. Parameter Collection
Collects and validates user inputs including repository details and server credentials.

### 2. Repository Management
Clones or updates the repository using PAT authentication.

### 3. SSH Connectivity
Establishes and validates SSH connection to remote server.

### 4. Environment Preparation
Installs and configures Docker, Docker Compose, and Nginx on remote server.

### 5. Application Deployment
Transfers files, builds Docker image, and runs container.

### 6. Nginx Configuration
Sets up reverse proxy to route HTTP traffic to containerized application.

### 7. Validation
Performs comprehensive health checks on all services.

### 8. Logging
Creates timestamped logs for troubleshooting and audit purposes.

## Log Files
All deployment activities are logged to `deploy_YYYYMMDD_HHMMSS.log`

## Error Handling
The script includes:
- Input validation
- Trap functions for unexpected errors
- Meaningful exit codes
- Comprehensive error messages

## Testing
- Application accessibility: `curl http://13.60.218.192`
- Container status: `docker ps`
- Nginx status: `systemctl status nginx`
- Application logs: `docker logs hng13-stage1-devops-container`

## Deployment Architecture
```
User → Nginx (Port 80) → Docker Container (Port 3000) → Node.js App
```

## Security Considerations
- PAT is not stored in files
- SSH key permissions validated
- Services run with appropriate user privileges

## Troubleshooting

### Cannot connect to remote server
- Verify security group allows SSH (port 22)
- Check SSH key permissions: `chmod 400 key.pem`

### Application not accessible
- Verify security group allows HTTP (port 80)
- Check Nginx status: `systemctl status nginx`
- Check container logs: `docker logs hng13-stage1-devops-container`

## Future Enhancements
- SSL/TLS certificate automation with Let's Encrypt
- Multi-environment support
- Rollback functionality
- Health monitoring and alerts

## License
MIT

## HNG Internship
This project was created as part of the HNG Internship Stage 1 DevOps track.
