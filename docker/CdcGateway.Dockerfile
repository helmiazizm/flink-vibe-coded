FROM python:3.11-slim

RUN apt-get update && apt-get install -y docker.io && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ../cdc_gateway/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ../cdc_gateway/ .

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "300", "app:app"]
