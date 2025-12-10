# Dockerfile
FROM python:3.12-slim

# Create non-root user and app dir
ENV APP_HOME=/app
RUN useradd --create-home --shell /bin/bash appuser && mkdir -p ${APP_HOME}
WORKDIR ${APP_HOME}

# Install dependencies without cache and remove apt lists to reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
 && rm -rf /var/lib/apt/lists/*

# Copy requirements first for Docker layer caching
COPY requirements.txt .

# Install Python deps as non-root user but need pip at build time
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files and set ownership to non-root user
COPY app.py .

RUN chown -R appuser:appuser ${APP_HOME}

# Switch to non-root user
USER appuser

# Expose port and set a safe default command
EXPOSE 8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app", "--workers", "1", "--threads", "4", "--timeout", "30"]
