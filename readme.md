agrovision/
├── .github/
│   └── workflows/
│       └── ci-cd.yml
├── data/
│   ├── raw/          # Dados brutos das fontes (ex: JSONs de API, imagens)
│   └── processed/    # Dados limpos e prontos para modelagem
├── notebooks/
│   └── 01_exploratory_data_analysis.ipynb
├── scripts/
│   ├── ingest.py     # Scripts para coletar dados
│   └── process.py    # Scripts para processar dados
├── src/
│   ├── __init__.py
│   ├── feature_engineering.py
│   ├── model.py
│   └── main.py       # Ponto de entrada da API/Dashboard
├── tests/
│   ├── __init__.py
│   └── test_feature_engineering.py
├── .dockerignore
├── .gitignore
├── Dockerfile
├── docker-compose.yml
├── README.md
└── requirements.txt
