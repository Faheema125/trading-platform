output "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  value       = aws_sns_topic.alarms.arn
}

output "alb_5xx_alarm_name" {
  description = "Name of the ALB 5xx alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx.alarm_name
}

output "unhealthy_targets_alarm_name" {
  description = "Name of the unhealthy targets alarm"
  value       = aws_cloudwatch_metric_alarm.unhealthy_targets.alarm_name
}
