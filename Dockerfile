FROM python:3.10-slim AS base

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1


RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gdal-bin \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

FROM base AS builder

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

FROM base AS final


COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin


COPY app.py .
COPY ./models ./models
COPY ./data/processed ./data/processed


EXPOSE 8501

# Define uma verificação de saúde para o contêiner
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health


# Define o ponto de entrada para executar a aplicação Streamlit com as
# configurações otimizadas para um ambiente de produção/proxy.
CMD [                                               \
    "streamlit", "run", "app.py",                   \
    "--server.port=8501",                           \
    "--server.address=0.0.0.0",                     \
    "--server.headless=true",                       \
    "--server.enableCORS=false",                    \
    "--server.enableXsrfProtection=false",          \
    "--server.enableWebsocketCompression=false",    \
    "--server.websocketPingInterval=20"             \
]