# ─────────────────────────────────────────────────────────────
# SNS Topic for Alarm Notifications
# ─────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-trading-alarms"

  tags = {
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ─────────────────────────────────────────────────────────────
# ALB 5xx Error Rate Alarm
# Fires when the API returns server errors
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.environment}-alb-5xx-errors"
  alarm_description   = "ALB is returning 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.api_target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# Unhealthy Target Count Alarm
# Fires when API tasks fail health checks
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.environment}-unhealthy-targets"
  alarm_description   = "One or more API targets are unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.api_target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# API Service CPU Alarm
# Fires when API CPU usage is sustained above 80%
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "api_cpu" {
  alarm_name          = "${var.environment}-api-cpu-high"
  alarm_description   = "API service CPU utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.api_service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# Worker Service CPU Alarm
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "worker_cpu" {
  alarm_name          = "${var.environment}-worker-cpu-high"
  alarm_description   = "Worker service CPU utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.worker_service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# RDS CPU Alarm
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.environment}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# RDS Free Storage Alarm
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.environment}-rds-storage-low"
  alarm_description   = "RDS free storage is below 2GB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2000000000 # 2GB in bytes

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = { Environment = var.environment }
}
