# Backend Deployment Assessment (StartupTech)

Terraform provisions AWS infrastructure for the MuchToDo Golang backend. The backend is containerized with Docker and run with Docker Compose on a private EC2 server behind an Application Load Balancer.

## Architecture

```
Internet -> ALB (public subnets, port 80) -> Backend EC2 (private subnet, port 8080) -> MongoDB
You -> Bastion (public subnet, SSH from my IP only) -> Backend EC2 (SSH)
```

- VPC `startuptech-vpc` (10.0.0.0/16), 2 public + 2 private subnets in 2 availability zones
- Internet Gateway, one NAT Gateway, public and private route tables
- Security groups: ALB (80/443 from anywhere), Bastion (22 from my IP), Backend (8080 from ALB, 22 from Bastion), MongoDB (27017 from Backend)
- EC2 (t3.micro, Amazon Linux 2): Bastion with Elastic IP, Backend with Docker + Docker Compose installed by user data, MongoDB server with MongoDB installed by user data
- Application Load Balancer with a target group on port 8080 and health check on `/health`

**Note on the database:** the app on the Backend EC2 uses the MongoDB container defined in `docker-compose.yml` (as Phase 2 requires). The separate MongoDB EC2 server is provisioned and running by Terraform, but the app does not connect to it.

## Repository structure

```
terraform/            Terraform code (main.tf, variables.tf, outputs.tf, user_data/)
app/                  MuchToDo backend source code
Dockerfile            Multi-stage build, non-root user, HEALTHCHECK
docker-compose.yml    Backend + MongoDB with volume, shared network, restart policies
.dockerignore
evidence/             Deployment screenshots
```

## Prerequisites

- AWS account and an IAM user with programmatic access (`aws configure`, region `us-east-1`)
- Terraform >= 1.5, AWS CLI v2, Git, Docker Desktop
- A Docker Hub account (the image is `karispearl/muchtodo-backend`, public)

## Phase 1: Provision the infrastructure

1. Create the SSH key pair once (skip if it already exists):

```
aws ec2 create-key-pair --key-name startuptech-key --query "KeyMaterial" --output text > startuptech-key.pem
```

   Keep `startuptech-key.pem` safe and never commit it.

2. Find your current public IP at https://ifconfig.me, then create `terraform/terraform.tfvars` (copy `terraform.tfvars.example`):

```
my_ip = "YOUR.IP.HERE/32"
```

   **If your IP changes later, update this value and run `terraform apply` again, or SSH to the bastion will time out.**

3. Run Terraform:

```
cd terraform
terraform init
terraform plan
terraform apply
```

   Type `yes` when asked. It takes about 5 minutes and ends with `Apply complete! Resources: 26 added`.

4. Note the outputs:

```
terraform output
```

   This shows `vpc_id`, `alb_dns_name`, `bastion_public_ip`, `backend_private_ip` and `mongodb_private_ip`.

## Phase 2: Build the Docker image

Do this on your own machine, not on the EC2 server (the t3.micro is too small to compile the Go app).

1. Create a `.env` file in the project root (it is git-ignored; see `.env.example`):

```
PORT=8080
MONGO_URI=mongodb://mongo:27017
DB_NAME=much_todo_db
JWT_SECRET_KEY=choose-a-long-random-secret
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=false
LOG_LEVEL=INFO
LOG_FORMAT=json
```

2. Build and test locally:

```
docker build -t muchtodo-backend .
docker compose up -d
docker compose ps
curl -i http://localhost:8080/health
```

   Expect `HTTP/1.1 200 OK` and `{"cache":"disabled","database":"ok"}`.

3. Push the image to Docker Hub (the server pulls it from there):

```
docker login
docker tag muchtodo-backend karispearl/muchtodo-backend:latest
docker push karispearl/muchtodo-backend:latest
```

## Deploy to the Backend EC2 server

1. From your machine, in the project root (where the `.pem` file is), SSH through the bastion to the backend. Use the values from `terraform output`:

```
ssh -i startuptech-key.pem -o "ProxyCommand=ssh -i startuptech-key.pem -W %h:%p ec2-user@BASTION_PUBLIC_IP" ec2-user@BACKEND_PRIVATE_IP
```

   Wait a few minutes after `terraform apply` so the user data script has finished installing Docker. Check with `docker --version`.

2. On the backend server, clone the repo and create the `.env` file (it is not in Git):

```
git clone https://github.com/Chidiogosezeh/backend-deployment-assessment.git
cd backend-deployment-assessment
cat > .env <<'EOF'
PORT=8080
MONGO_URI=mongodb://mongo:27017
DB_NAME=much_todo_db
JWT_SECRET_KEY=choose-a-long-random-secret
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=false
LOG_LEVEL=INFO
LOG_FORMAT=json
EOF
```

3. Start the application (it downloads the prebuilt image, so nothing is compiled on the server):

```
docker compose pull backend
docker compose up -d --no-build
docker compose ps
curl -i http://localhost:8080/health
```

4. Verify through the load balancer from your own machine. Wait 1 to 2 minutes for the target to turn healthy:

```
curl -i http://ALB_DNS_NAME/health
```

   The ALB DNS name comes from `terraform output alb_dns_name`.

## Evidence

Screenshots for every required step are in the `evidence/` folder (numbered 1 to 14). The Terraform plan screenshots are in `evidence/2. terraform-plan/`.

## Teardown / cleanup

To stop all AWS charges:

```
cd terraform
terraform destroy
```

Type `yes`. This deletes all 26 resources (VPC, NAT Gateway, ALB, EC2 instances, Elastic IPs). The key pair `startuptech-key` is not managed by Terraform, so delete it separately if you no longer need it:

```
aws ec2 delete-key-pair --key-name startuptech-key
```

Then confirm in the AWS Console (EC2, VPC, Load Balancers) that nothing is left running.

## Rebuilding after a teardown

1. Check your current IP and update `my_ip` in `terraform/terraform.tfvars`.
2. Make sure `startuptech-key` still exists in AWS and `startuptech-key.pem` is on your machine.
3. Run `terraform apply`, then follow "Deploy to the Backend EC2 server" again. The bastion IP, backend IP and ALB DNS name will be new, so read them from `terraform output`.

## Troubleshooting

- **SSH times out:** your public IP changed. Update `my_ip` and run `terraform apply`.
- **Key permission error on Windows:** run `icacls startuptech-key.pem /inheritance:r` and then grant your own user read access.
- **Target group shows unhealthy:** the app is not running on the backend yet, or the `.env` file is missing on the server.
- **Backend container keeps restarting:** the `.env` file is missing or wrong. The app only reads its settings from the `.env` file mounted at `/app/.env`.
The Terraform state from the deployed environment is saved in state/terraform.tfstate.
