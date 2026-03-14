FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    apscheduler \
    boto3 \
    requests \
    pytz \
    tenacity

COPY main.py .

CMD ["python", "main.py"]
