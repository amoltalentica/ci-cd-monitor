from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime, timezone
import time
import os

from app.core.database import get_db
from app.schemas.pipeline import HealthResponse
from app.services.github_service import GitHubService
from app.services.slack_service import SlackService
from app.core.config import settings

router = APIRouter()

# Track application start time
START_TIME = time.time()

@router.get("/health", response_model=HealthResponse)
async def health_check(db: Session = Depends(get_db)):
    """Health check endpoint"""
    try:
        # Check database connection
        db.execute(text("SELECT 1"))
        db_status = "healthy"
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"
    
    # Check GitHub API connection
    github_status = "not_configured"
    if settings.GITHUB_TOKEN:
        try:
            github_service = GitHubService()
            await github_service.test_connection()
            github_status = "healthy"
        except Exception as e:
            github_status = f"unhealthy: {str(e)}"
    
    # Check Slack webhook connection
    slack_status = "not_configured"
    if settings.SLACK_WEBHOOK_URL:
        try:
            slack_service = SlackService()
            await slack_service.test_connection()
            slack_status = "healthy"
        except Exception as e:
            slack_status = f"unhealthy: {str(e)}"
    
    # Calculate uptime
    uptime = time.time() - START_TIME
    
    return HealthResponse(
        status="healthy" if db_status == "healthy" else "unhealthy",
        timestamp=datetime.now(timezone.utc),
        version=settings.APP_VERSION,
        uptime=uptime,
        database=db_status,
        github=github_status,
        slack=slack_status
    )

@router.get("/ping")
async def ping():
    """Simple ping endpoint"""
    return {"message": "pong", "timestamp": datetime.now(timezone.utc)}
