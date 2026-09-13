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
                  body { background-color: #0f172a; color: #f8fafc; font-family: system-ui, sans-serif; }
                  .card { background-color: #1e293b; border: 1px solid #334155; border-radius: 12px; }
                  .form-control, .form-select { background-color: #0f172a; border: 1px solid #334155; color: #f8fafc; }
                  .form-control:focus, .form-select:focus { background-color: #0f172a; color: #fff; border-color: #38bdf8; box-shadow: none; }
                </style>
              </head>
              <body>
              <div class="container py-5">
                <div class="row justify-content-center">
                  <div class="col-md-6">
                    <div id="formCard" class="card p-4 shadow">
                      <h3 class="text-center mb-3">Feedback &amp; Registration</h3>
                      <p class="text-secondary text-center small mb-4">AWS 3-Tier Infrastructure &bull; EC2 Private Subnet &bull; ALB</p>
                      <form id="feedbackForm" onsubmit="handleSubmit(event)">
                        <div class="mb-3">
                          <label class="form-label">Full Name</label>
                          <input type="text" class="form-control" id="nameInput" placeholder="Enter your name" required>
                        </div>
                        <div class="mb-3">
                          <label class="form-label">Email</label>
                          <input type="email" class="form-control" id="emailInput" placeholder="Enter your email" required>
                        </div>
                        <div class="mb-3">
                          <label class="form-label">Category</label>
                          <select class="form-select" id="topicInput" required>
                            <option value="DevOps Assessment">DevOps Assessment</option>
                            <option value="Terraform Architecture">Terraform Architecture</option>
                            <option value="General Feedback">General Feedback</option>
                          </select>
                        </div>
                        <div class="mb-3">
                          <label class="form-label">Message</label>
                          <textarea class="form-control" id="msgInput" rows="3" placeholder="Enter message" required></textarea>
                        </div>
                        <button type="submit" class="btn btn-primary w-100">Submit</button>
                      </form>
                    </div>

                    <div id="thankYouCard" class="card p-4 text-center shadow d-none">
                      <h2 class="text-success mb-2">Thank You!</h2>
                      <p class="text-secondary">Your feedback response was recorded successfully.</p>
                      <div class="text-start bg-dark p-3 rounded mb-3 small">
                        <div><strong>Name:</strong> <span id="resName"></span></div>
                        <div><strong>Email:</strong> <span id="resEmail"></span></div>
                        <div><strong>Category:</strong> <span id="resTopic"></span></div>
                        <div><strong>Message:</strong> <span id="resMsg"></span></div>
                      </div>
                      <button class="btn btn-outline-light btn-sm" onclick="resetForm()">Submit Another Response</button>
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
