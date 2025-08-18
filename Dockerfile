
FROM python:3.10-slim AS base

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# dependências do sistema
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gdal-bin \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

# Este estágio aproveita o cache do Docker para acelerar builds futuros.
FROM base AS builder

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Constrói a imagem final, limpa e otimizada para produção.
FROM base AS final

# Copia o ambiente virtual com as dependências instaladas do estágio 'builder'
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin


COPY app.py .
COPY ./models ./models
COPY ./data/processed ./data/processed

EXPOSE 8501

HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
