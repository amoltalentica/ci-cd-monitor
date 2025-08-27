 Example Prompts for CI-CD dashboard monitoring Project
---

## 1. Project Initialization
**Prompt:**  
"Create a production-grade CI/CD Pipeline Health Dashboard using React (frontend), FastAPI (backend), and PostgreSQL as database."  

**AI Response:**  
Sure! We'll create a three-tier architecture with the following:  
- **Frontend:** React + TailwindCSS for a modern UI  
- **Backend:** FastAPI for metrics API  
- **Database:** PostgreSQL for storing pipeline execution data  
- **Infrastructure:** Docker + Docker Compose for containerized deployment  

---

**Prompt:**  
"Set up Docker and Docker Compose files for frontend, backend, and database services."  

**AI Response:**  
I'll generate a `docker-compose.yml` that includes:  
- **frontend** service (React app served via Nginx)  
- **backend** service (FastAPI app on port 8000)  
- **db** service (PostgreSQL with persistent volume)  
- Network to connect services  

---

## 2. Backend (FastAPI)
**Prompt:**  
"Write a FastAPI backend to expose `/api/metrics` endpoint for CI/CD pipeline metrics."  

**AI Response:**  
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/api/metrics")
def get_metrics():
    return {"success_rate": 95, "failure_rate": 5, "avg_build_time": "4m30s"}
```

---

**Prompt:**  
"Add a `/health` endpoint to check service availability."  

**AI Response:**  
```python
@app.get("/health")
def health_check():
    return {"status": "ok"}
```

---

**Prompt:**  
"Integrate PostgreSQL using SQLAlchemy for storing pipeline execution details."  

**AI Response:**  
- Install SQLAlchemy and async driver.  
- Create `PipelineRun` model with fields: id, workflow_name, status, duration, timestamp.  
- Add CRUD operations to store workflow runs into the DB.  

---

## 3. Frontend (React + Tailwind + Recharts)
**Prompt:**  
"Create a React dashboard with TailwindCSS for styling."  

**AI Response:**  
- Initialize React project with Vite.  
- Install TailwindCSS.  
- Create a `Dashboard` component with grid layout for charts.  

---

**Prompt:**  
"Add charts (success vs. failure, build duration trends) using Recharts."  

**AI Response:**  
```jsx
<ResponsiveContainer width="100%" height={300}>
  <PieChart>
    <Pie dataKey="value" data={data} fill="#8884d8" label />
  </PieChart>
</ResponsiveContainer>
```

---

## 4. Database (PostgreSQL)
**Prompt:**  
"Design a PostgreSQL schema to store pipeline runs with fields: id, workflow_name, status, duration, timestamp."  

**AI Response:**  
```sql
CREATE TABLE pipeline_runs (
  id SERIAL PRIMARY KEY,
  workflow_name VARCHAR(255),
  status VARCHAR(20),
  duration INT,
  timestamp TIMESTAMP DEFAULT NOW()
);
```

---

## 5. CI/CD Integration
**Prompt:**  
"Fetch GitHub Actions workflow execution data using GitHub API."  

**AI Response:**  
- Use GitHub REST API `GET /repos/{owner}/{repo}/actions/runs`.  
- Parse response and insert workflow runs into PostgreSQL.  
- Store GitHub token in `.env` for authentication.  

---

## 6. Slack Integration (Optional)
**Prompt:**  
"Add Slack webhook integration to send alerts for failed pipelines."  

**AI Response:**  
- Use `requests.post(SLACK_WEBHOOK_URL, json={...})` in FastAPI.  
- Trigger Slack alert when workflow status = `failure`.  

---

## 7. Deployment
**Prompt:**  
"Write Dockerfiles for backend and frontend."  

**AI Response:**  
- **Backend Dockerfile:** Python base, install dependencies, expose port 8000.  
- **Frontend Dockerfile:** Node.js build, serve via Nginx.  

**Prompt:**  
"Write `docker-compose.yml` to run all services together."  

**AI Response:**  
- Compose includes `frontend`, `backend`, `db`, and `nginx`.  
- Each service connected via internal network.  

---

## 8. Monitoring & Alerts
**Prompt:**  
"Expose Prometheus-compatible metrics from FastAPI."  

**AI Response:**  
- Add `/metrics` endpoint with Prometheus text format.  
- Integrate `prometheus-client` Python library.  

---
