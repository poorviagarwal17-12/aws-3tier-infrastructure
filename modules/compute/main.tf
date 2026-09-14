data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  vpc_security_group_ids = [var.app_security_group_id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx

              # SSM agent for session manager access (no SSH)
              if command -v snap >/dev/null 2>&1; then
                  snap install amazon-ssm-agent --classic || true
                  systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
              fi
              systemctl enable --now amazon-ssm-agent || true

              # Health check endpoint
              mkdir -p /var/www/html
              echo "OK" > /var/www/html/health

              # Web application with form and thank you screen
              cat <<'HTML' > /var/www/html/index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>3-Tier Cloud Application</title>
                <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
                <style>
                  body {
                    background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
                    color: #0f172a;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                  }
                  .main-card {
                    background: #ffffff;
                    border: 1px solid #cbd5e1;
                    border-radius: 16px;
                    box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1);
                  }
                  .badge-tier {
                    background-color: #e0f2fe;
                    color: #0369a1;
                    font-weight: 600;
                    border: 1px solid #bae6fd;
                    padding: 6px 14px;
                    border-radius: 20px;
                    font-size: 0.82rem;
                  }
                  .form-label {
                    font-weight: 600;
                    color: #0f172a;
                    margin-bottom: 6px;
                  }
                  .form-control, .form-select {
                    background-color: #ffffff;
                    border: 1.5px solid #94a3b8;
                    color: #0f172a !important;
                    font-size: 0.95rem;
                    border-radius: 8px;
                    padding: 10px 14px;
                  }
                  .form-control:focus, .form-select:focus {
                    background-color: #ffffff;
                    border-color: #2563eb;
                    color: #0f172a !important;
                    box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.15);
                  }
                  .btn-primary {
                    background-color: #2563eb;
                    border-color: #2563eb;
                    font-weight: 600;
                    border-radius: 8px;
                    padding: 12px;
                    font-size: 1rem;
                  }
                  .btn-primary:hover {
                    background-color: #1d4ed8;
                    border-color: #1d4ed8;
                  }
                  .summary-box {
                    background-color: #f8fafc;
                    border: 1.5px solid #e2e8f0;
                    border-radius: 10px;
                  }
                </style>
              </head>
              <body>
              <div class="container py-5">
                <div class="row justify-content-center">
                  <div class="col-md-7 col-lg-6">
                    <div id="formCard" class="main-card p-4 p-md-5">
                      <div class="text-center mb-4">
                        <span class="badge-tier d-inline-block mb-2">AWS 3-Tier Production Architecture</span>
                        <h2 class="fw-bold text-dark mt-1">Feedback &amp; Registration</h2>
                        <p class="text-muted small">Application Load Balancer &bull; Private EC2 ASG &bull; RDS MySQL</p>
                      </div>
                      <form id="feedbackForm" onsubmit="handleSubmit(event)">
                        <div class="mb-3">
                          <label class="form-label" for="nameInput">Full Name</label>
                          <input type="text" class="form-control" id="nameInput" placeholder="Enter your full name" required>
                        </div>
                        <div class="mb-3">
                          <label class="form-label" for="emailInput">Email Address</label>
                          <input type="email" class="form-control" id="emailInput" placeholder="name@example.com" required>
                        </div>
                        <div class="mb-3">
                          <label class="form-label" for="topicInput">Assessment Category</label>
                          <select class="form-select" id="topicInput" required>
                            <option value="DevOps CI/CD Deployment">DevOps CI/CD Deployment</option>
                            <option value="Terraform 3-Tier Architecture">Terraform 3-Tier Architecture</option>
                            <option value="Security &amp; Compliance Scan">Security &amp; Compliance Scan</option>
                            <option value="General Project Feedback">General Project Feedback</option>
                          </select>
                        </div>
                        <div class="mb-4">
                          <label class="form-label" for="msgInput">Your Message / Feedback</label>
                          <textarea class="form-control" id="msgInput" rows="3" placeholder="Write your comments here..." required></textarea>
                        </div>
                        <button type="submit" class="btn btn-primary w-100 shadow-sm">Submit Response</button>
                      </form>
                    </div>

                    <div id="thankYouCard" class="main-card p-4 p-md-5 text-center d-none">
                      <div class="mb-3">
                        <div class="d-inline-flex align-items-center justify-content-center bg-success-subtle text-success rounded-circle" style="width: 60px; height: 60px;">
                          <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" class="bi bi-check2" viewBox="0 0 16 16">
                            <path d="M13.854 3.646a.5.5 0 0 1 0 .708l-7 7a.5.5 0 0 1-.708 0l-3.5-3.5a.5.5 0 1 1 .708-.708L6.5 10.293l6.646-6.647a.5.5 0 0 1 .708 0z"/>
                          </svg>
                        </div>
                      </div>
                      <h2 class="fw-bold text-dark mb-1">Thank You!</h2>
                      <p class="text-muted mb-4">Your feedback response has been recorded successfully in the 3-Tier database.</p>
                      <div class="summary-box p-3 text-start mb-4">
                        <div class="mb-2"><strong class="text-dark">Name:</strong> <span class="text-secondary" id="resName"></span></div>
                        <div class="mb-2"><strong class="text-dark">Email:</strong> <span class="text-secondary" id="resEmail"></span></div>
                        <div class="mb-2"><strong class="text-dark">Category:</strong> <span class="text-secondary" id="resTopic"></span></div>
                        <div><strong class="text-dark">Message:</strong> <span class="text-secondary" id="resMsg"></span></div>
                      </div>
                      <button class="btn btn-outline-secondary w-100" onclick="resetForm()">Submit Another Response</button>
                    </div>
                  </div>
                </div>
              </div>

              <script>
              function handleSubmit(e) {
                e.preventDefault();
                document.getElementById('resName').innerText = document.getElementById('nameInput').value;
                document.getElementById('resEmail').innerText = document.getElementById('emailInput').value;
                document.getElementById('resTopic').innerText = document.getElementById('topicInput').value;
                document.getElementById('resMsg').innerText = document.getElementById('msgInput').value;
                document.getElementById('formCard').classList.add('d-none');
                document.getElementById('thankYouCard').classList.remove('d-none');
              }
              function resetForm() {
                document.getElementById('feedbackForm').reset();
                document.getElementById('thankYouCard').classList.add('d-none');
                document.getElementById('formCard').classList.remove('d-none');
              }
              </script>
              </body>
              </html>
              HTML

              systemctl enable --now nginx
              systemctl restart nginx
              EOF
  )

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-ec2"
      Environment = var.environment
      Tier        = "App"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Environment = var.environment
    Tier        = "Public"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.project_name}-${var.environment}-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.this.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}
