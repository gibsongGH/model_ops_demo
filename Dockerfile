# Use a slim Python base
FROM python:3.9-slim

# Good defaults
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Workdir
WORKDIR /app

# System libs: libgomp1 is needed by LightGBM/XGBoost wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage cache
COPY requirements.txt .

# Prefer wheels; avoid building from source on slim
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --prefer-binary -r requirements.txt

# Copy app code (only what you need)
COPY app.py .
COPY templates/ ./templates/
# Put model at /models/model.pkl to match ENV below
COPY models/model.pkl /models/model.pkl

# Model path used by your app
ENV MODEL_PATH=/models/model.pkl

# Create non-root user and give ownership
RUN useradd --create-home --uid 1000 appuser \
    && chown -R appuser:appuser /app /models
USER appuser

# Expose app port
EXPOSE 8000

# Health check 
HEALTHCHECK CMD python -c "import urllib.request,sys; \
  sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)"

# Start the server
# If you're using FastAPI/Starlette (ASGI), keep uvicorn:
CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]

# If you're using Flask/Werkzeug (WSGI), replace the line above with:
# CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "app:app"]