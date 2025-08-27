# CI/CD Monitor

A production-ready dashboard to monitor CI/CD pipelines (GitHub Actions, Jenkins, etc.) with real-time metrics, alerts, and visualization.

## 🚀 Setup & Run Instructions

1. **Clone the repository**
   ```bash
   git clone git@github.com:amoltalentica/ci-cd-monitor.git
   cd ci-cd-monitor
   ```

2. **Configure environment variables**
   Create a `.env` file in the root directory with the following values:
   ```ini
   # GitHub Configuration
   GITHUB_TOKEN=your_github_token
   GITHUB_OWNER=your_github_username
   GITHUB_REPO=your_repository_name

   # Database Configuration
   POSTGRES_DB=cicd_dashboard
   POSTGRES_USER=cicd_user
   POSTGRES_PASSWORD=secure_password
   POSTGRES_HOST=db
   POSTGRES_PORT=5432

   # Slack Integration (Optional)
   SLACK_WEBHOOK_URL=

   # Application Configuration
   BACKEND_PORT=8000
   FRONTEND_PORT=3000
   ```

3. **Run with Docker Compose**
   ```bash
   docker compose up -d --build
   ```

4. **Access the application**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000

---

## 🏗 Architecture Summary

The system follows a **modular microservices architecture**:

- **Frontend**: React + Tailwind dashboard for visualization of pipeline health metrics.
- **Backend**: FastAPI service that fetches, stores, and processes pipeline data.
- **Database**: PostgreSQL for storing workflow runs, metrics, and alert history.
- **Integrations**:
  - GitHub Actions API for workflow run data.
  - Slack Webhooks for failure alerts.
- **Deployment**: Docker Compose for local setup, extendable to AWS ECS/EC2.

---

## 🤖 How AI Tools Were Used

This project was built with assistance from AI tools (ChatGPT & Copilot) to:
- Generate boilerplate code for FastAPI & React setup.
- Create SQL schema migrations for storing pipeline data.
- Write Docker Compose configuration with environment variables.
- Debug container-to-container network issues.

### Example Prompts Used:
- *"Write a FastAPI endpoint to fetch GitHub Actions workflow run data."*
- *"Generate a Docker Compose file with frontend, backend, and Postgres services."*
- *"Fix Docker networking issue: backend cannot connect to db."*

---

## 📚 Key Learnings & Assumptions

- **Learnings**:
  - Docker networking requires services to use container names instead of `localhost`.
  - GitHub Actions API pagination must be handled for large repositories.
  - React + FastAPI integration works seamlessly with CORS configuration.

- **Assumptions**:
  - The user has Docker & Docker Compose installed.
  - GitHub token provided has `repo` and `workflow` access.
  - Basic knowledge of CI/CD tools is available for setup.

---

## ✅ Next Steps

- Add Jenkins integration as a data source.
- Extend notification channels (Email, MS Teams).
- Deploy production version on AWS (ECS + RDS + ALB).
