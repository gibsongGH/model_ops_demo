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

# Copy model
COPY models/ ./models/

# Create non-root user and give ownership
RUN useradd --create-home --uid 1000 appuser \
    && chown -R appuser:appuser /app
USER appuser

# Expose ports commonly used by hosting platforms
# - 7860 is commonly used by Hugging Face Spaces
# - 8000 is commonly used by Render and local dev
EXPOSE 7860 8000

# Health check (uses PORT environment variable if provided)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import os,urllib.request,sys; p=int(os.environ.get('PORT', 8000)); sys.exit(0 if urllib.request.urlopen(f'http://127.0.0.1:{p}/health').status==200 else 1)"

# Start the server using the PORT env var (default 8000).
# Use shell form so ${PORT:-8000} is expanded.
CMD ["sh", "-c", "python -m uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]

# If you're using Flask/Werkzeug (WSGI), replace the line above with:
# CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "app:app"]