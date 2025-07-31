# ==============================================================================
# app.py - Dashboard Interativo para o AgroVision
# ==============================================================================

import streamlit as st
import pandas as pd
import joblib
import numpy as np

# --- Configuração da Página ---
st.set_page_config(
    page_title="AgroVision - Previsão de Safras",
    page_icon="🌽",
    layout="wide"
)

# --- Carregamento do Modelo ---
# Usa um cache para carregar o modelo apenas uma vez
@st.cache_resource
def carregar_modelo():
    """Carrega o modelo treinado do arquivo."""
    try:
        # Certifique-se de que o nome do modelo corresponde ao que foi salvo
        modelo = joblib.load('models/agrovision_random_forest_v1.joblib')
        return modelo
    except FileNotFoundError:
        st.error("Arquivo do modelo não encontrado. Certifique-se de que 'models/agrovision_random_forest_v1.joblib' existe.")
        return None

modelo = carregar_modelo()

# --- Interface do Usuário (UI) ---
st.title("🌽 AgroVision: Sistema de Previsão de Produtividade de Milho")
st.markdown("Insira os dados da sua região para obter uma previsão de rendimento da safra.")

# Dividir a tela em colunas para melhor organização
col1, col2 = st.columns(2)

with col1:
    st.subheader("🌍 Dados Geográficos")
    # Usa valores médios do seu dataset como padrão
    latitude = st.number_input("Latitude", min_value=-34.0, max_value=5.0, value=-18.5, format="%.4f")
    longitude = st.number_input("Longitude", min_value=-74.0, max_value=-34.0, value=-54.5, format="%.4f")
    
    st.subheader("🗓️ Período")
    ano = st.slider("Ano da Safra para Previsão", min_value=2024, max_value=2030, value=2025)

with col2:
    st.subheader("🌦️ Dados Ambientais")
    precipitacao = st.number_input("Precipitação Média Anual (mm/dia)", min_value=0.0, value=3.5, format="%.2f")
    temp_max = st.number_input("Temperatura Máxima Média Anual (°C)", min_value=20.0, value=32.0, format="%.2f")
    temp_min = st.number_input("Temperatura Mínima Média Anual (°C)", min_value=-5.0, value=20.0, format="%.2f")
    
    # ADICIONADO: Campo para o NDVI
    ndvi = st.number_input(
        "NDVI Máximo da Safra", 
        min_value=0.0, 
        max_value=1.0, 
        value=0.75, 
        format="%.4f",
        help="Índice de Vegetação por Diferença Normalizada - uma medida da saúde da vegetação obtida por satélite."
    )


# Botão para fazer a previsão
if st.button("📊 Gerar Previsão", use_container_width=True):
    if modelo is not None:
        # Criar um DataFrame com os dados de entrada
        # feature 'ndvi_max_safra'
        dados_entrada = pd.DataFrame({
            'ano': [ano],
            'latitude': [latitude],
            'longitude': [longitude],
            'precipitacao_media_anual': [precipitacao],
            'temp_max_media_anual': [temp_max],
            'temp_min_media_anual': [temp_min],
            'ndvi_max_safra': [ndvi]
        })
        
        # Fazer a previsão
        previsao = modelo.predict(dados_entrada)
        
        # Exibir o resultado
        st.success("### Previsão de Rendimento Gerada!")
        st.metric(
            label="Rendimento Médio Estimado",
            value=f"{previsao[0]:.2f} kg/ha",
            help="Esta é a previsão da produtividade em quilogramas por hectare."
        )
    else:
        st.error("O modelo não pôde ser carregado. A previsão não pode ser gerada.")
