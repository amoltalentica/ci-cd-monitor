from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import Optional
from datetime import datetime, timezone

from app.core.database import get_db
from app.models.pipeline import Pipeline, Alert
from app.schemas.pipeline import Pipeline as PipelineSchema, PipelineList, SyncResponse
from app.services.github_service import GitHubService
from app.services.slack_service import SlackService

router = APIRouter()


@router.get("/", response_model=PipelineList)
async def get_pipelines(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    status: Optional[str] = Query(None),
    workflow: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    try:
        query = db.query(Pipeline)
        if status:
            query = query.filter(Pipeline.status == status)
        if workflow:
            query = query.filter(Pipeline.workflow_name == workflow)

        total = query.count()
        offset = (page - 1) * limit
        pipelines = query.order_by(desc(Pipeline.created_at)).offset(offset).limit(limit).all()
        pages = (total + limit - 1) // limit

        return PipelineList(pipelines=pipelines, total=total, page=page, limit=limit, pages=pages)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch pipelines: {str(e)}")


@router.get("/latest", response_model=PipelineSchema)
async def get_latest_pipeline(db: Session = Depends(get_db)):
    try:
        pipeline = db.query(Pipeline).order_by(desc(Pipeline.created_at)).first()
        if not pipeline:
            raise HTTPException(status_code=404, detail="No pipelines found")
        return pipeline
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch latest pipeline: {str(e)}")


@router.get("/{pipeline_id}", response_model=PipelineSchema)
async def get_pipeline(pipeline_id: int, db: Session = Depends(get_db)):
    try:
        pipeline = db.query(Pipeline).filter(Pipeline.id == pipeline_id).first()
        if not pipeline:
            raise HTTPException(status_code=404, detail="Pipeline not found")
        return pipeline
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch pipeline: {str(e)}")


@router.post("/sync", response_model=SyncResponse)
async def sync_pipelines(db: Session = Depends(get_db)):
    """
    Fetch GitHub Actions pipelines, update DB, and send Slack notifications once per pipeline.
    """
    try:
        github_service = GitHubService()
        slack_service = SlackService()

        new_pipelines = await github_service.sync_workflow_runs(db)
        total_executions = db.query(Pipeline).count()

        for pipeline in new_pipelines:
            try:
                if pipeline.status == "completed":
                    # Check if this pipeline has already been notified
                    existing_alert = db.query(Alert).filter(
                        Alert.pipeline_id == pipeline.id
                    ).first()
                    if existing_alert:
                        continue  # Skip already notified pipelines

                    if pipeline.conclusion == "failure":
                        sent = await slack_service.send_pipeline_failure_alert(pipeline)
                        alert_status = "sent" if sent else "failed"
                        a = Alert(
                            pipeline_id=pipeline.id,
                            alert_type="pipeline_failure",
                            message=f"Slack notification {alert_status}",
                            status=alert_status
                        )
                        db.add(a)
                        try:
                            db.commit()
                        except Exception:
                            db.rollback()

                    elif pipeline.conclusion == "success":
                        sent = await slack_service.send_pipeline_success_notification(pipeline)
                        a = Alert(
                            pipeline_id=pipeline.id,
                            alert_type="pipeline_success",
                            message=f"Slack notification {'sent' if sent else 'failed'}",
                            status="sent" if sent else "failed"
                        )
                        db.add(a)
                        try:
                            db.commit()
                        except Exception:
                            db.rollback()

            except Exception as e:
                print(f"[WARN] Slack notification failed for pipeline {pipeline.id}: {str(e)}")

        return SyncResponse(
            success=True,
            message=f"Successfully synced {len(new_pipelines)} pipeline executions",
            new_executions=len(new_pipelines),
            total_executions=total_executions,
            sync_time=datetime.now(timezone.utc)
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to sync pipelines: {str(e)}")


@router.get("/stats/summary")
async def get_pipeline_stats(db: Session = Depends(get_db)):
    try:
        total = db.query(Pipeline).count()
        success_count = db.query(Pipeline).filter(Pipeline.status == "completed", Pipeline.conclusion == "success").count()
        failure_count = db.query(Pipeline).filter(Pipeline.status == "completed", Pipeline.conclusion == "failure").count()
        running_count = db.query(Pipeline).filter(Pipeline.status == "in_progress").count()
        completed_count = success_count + failure_count
        success_rate = (success_count / completed_count * 100) if completed_count else 0

        avg_build_time = db.query(Pipeline.duration).filter(Pipeline.status == "completed", Pipeline.duration.isnot(None)).all()
        avg_duration = sum([p[0] for p in avg_build_time]) / len(avg_build_time) if avg_build_time else 0

        return {
            "total_pipelines": total,
            "success_count": success_count,
            "failure_count": failure_count,
            "running_count": running_count,
            "success_rate": round(success_rate, 2),
            "average_build_time": round(avg_duration, 2)
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch pipeline stats: {str(e)}")

