FROM python:3.12-slim

WORKDIR /app

# Install claude CLI dependencies (node for claude)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY klaudimero/ klaudimero/

EXPOSE 8585

CMD ["uvicorn", "klaudimero.main:app", "--host", "0.0.0.0", "--port", "8585"]
