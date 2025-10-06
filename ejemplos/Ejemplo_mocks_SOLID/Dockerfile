#Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["bash", "-lc", "make gates && python -m app.main"]
