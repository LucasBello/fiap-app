FROM python:3.9-slim

# Define um diretório para montar o volume persistente
VOLUME /app/data

WORKDIR /app

COPY requirements.txt requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "app.py"]