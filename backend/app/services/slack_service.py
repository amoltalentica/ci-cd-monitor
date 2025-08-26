import httpx
from datetime import datetime
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.pipeline import Pipeline, Alert

class SlackService:
    def __init__(self):
        self.webhook_url = settings.SLACK_WEBHOOK_URL

    async def send_notifications_for_completed_runs(self, pipelines: list[Pipeline], db: Session):
        """
        Iterates through completed pipelines and sends Slack notifications if not already sent.
        This is the main isolated function for handling notifications.
        """
        if not self.webhook_url:
            print("[Slack] Webhook URL not configured, skipping all notifications.")
            return

        alerts_to_add = []
        for pipeline in pipelines:
            # Only send notifications for pipelines that have finished
            if pipeline.status != "completed":
                continue

            # Check if an alert for this pipeline has already been sent
            existing_alert = db.query(Alert).filter(Alert.pipeline_id == pipeline.id).first()
            if existing_alert:
                continue

            print(f"[Slack] Pipeline {pipeline.id} completed. Preparing notification...")

            # Send success or failure alert
            if pipeline.conclusion == "success":
                sent = await self.send_pipeline_success_notification(pipeline)
                alert_type = "pipeline_success"
            elif pipeline.conclusion == "failure":
                sent = await self.send_pipeline_failure_alert(pipeline)
                alert_type = "pipeline_failure"
            else:
                continue # Skip for other conclusions like 'cancelled'

            # Create an alert record to prevent future duplicates
            alert_status = "sent" if sent else "failed"
            new_alert = Alert(
                pipeline_id=pipeline.id,
                alert_type=alert_type,
                message=f"Slack notification {alert_status}",
                status=alert_status,
            )
            alerts_to_add.append(new_alert)

        if alerts_to_add:
            db.add_all(alerts_to_add)
            db.commit()
            print(f"[Slack] Processed {len(alerts_to_add)} new notifications.")


    async def send_pipeline_failure_alert(self, pipeline: Pipeline) -> bool:
        return await self._send_pipeline_message(pipeline, success=False)

    async def send_pipeline_success_notification(self, pipeline: Pipeline) -> bool:
        return await self._send_pipeline_message(pipeline, success=True)

    async def _send_pipeline_message(self, pipeline: Pipeline, success: bool) -> bool:
        status_emoji = "✅" if success else "❌"
        status_text = "Success" if success else "Failure"
        color = "#36a64f" if success else "#d50200"

        duration_str = "N/A"
        if pipeline.duration is not None:
            minutes, seconds = divmod(pipeline.duration, 60)
            duration_str = f"{minutes}m {seconds}s"

        started_at_str = pipeline.started_at.strftime('%Y-%m-%d %H:%M:%S UTC') if pipeline.started_at else 'N/A'

        message = {
            "attachments": [
                {
                    "color": color,
                    "blocks": [
                        {
                            "type": "header",
                            "text": {"type": "plain_text", "text": f"{status_emoji} Pipeline {status_text}: {pipeline.workflow_name}"}
                        },
                        {
                            "type": "section",
                            "fields": [
                                {"type": "mrkdwn", "text": f"*Branch:*\n`{pipeline.branch or 'N/A'}`"},
                                {"type": "mrkdwn", "text": f"*Triggered by:*\n{pipeline.actor or 'N/A'}"},
                                {"type": "mrkdwn", "text": f"*Duration:*\n{duration_str}"},
                                {"type": "mrkdwn", "text": f"*Started At:*\n{started_at_str}"},
                            ]
                        },
                        {
                            "type": "section",
                            "text": {"type": "mrkdwn", "text": f"*Commit:*\n>_{pipeline.commit_message or 'No commit message.'}_"}
                        },
                        {
                            "type": "actions",
                            "elements": [
                                {
                                    "type": "button",
                                    "text": {"type": "plain_text", "text": "View Workflow Run"},
                                    "style": "primary" if success else "danger",
                                    "url": pipeline.html_url
                                }
                            ]
                        }
                    ]
                }
            ]
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(self.webhook_url, json=message, timeout=10.0)
                if response.status_code == 200:
                    print(f"[Slack] {status_text} notification sent for pipeline {pipeline.id}")
                    return True
                print(f"[Slack] Failed to send {status_text} notification for pipeline {pipeline.id}: {response.status_code} {response.text}")
        except Exception as e:
            print(f"[Slack] Exception sending {status_text} notification for pipeline {pipeline.id}: {e}")
        return False
