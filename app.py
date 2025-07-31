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

# --- Funções de Carregamento de Dados (com cache) ---

@st.cache_resource
def carregar_modelo():
    """Carrega o modelo treinado do arquivo."""
    try:
        modelo = joblib.load('models/agrovision_random_forest_v1.joblib')
        return modelo
    except FileNotFoundError:
        return None

@st.cache_data
def carregar_dados_localizacao():
    """Carrega os dados para obter a lista de municípios e coordenadas."""
    try:
        # Usamos o nosso dataset que já tem as coordenadas
        caminho_dados = 'data/processed/dataset_completo_com_clima.csv'
        df = pd.read_csv(caminho_dados)
        # Selecionamos apenas as colunas necessárias e removemos duplicados
        df_localizacoes = df[['municipio_nome', 'uf', 'latitude', 'longitude']].drop_duplicates().sort_values(by='municipio_nome')
        # Criamos uma coluna de exibição "Nome (UF)"
        df_localizacoes['display_name'] = df_localizacoes['municipio_nome'] + ' (' + df_localizacoes['uf'] + ')'
        return df_localizacoes
    except FileNotFoundError:
        return None

# --- Carregamento Inicial ---
modelo = carregar_modelo()
df_localizacoes = carregar_dados_localizacao()

# --- Interface do Usuário (UI) ---
st.title("🌽 AgroVision: Sistema de Previsão de Produtividade de Milho")
st.markdown("Selecione o município e insira os dados da safra para obter uma previsão de rendimento.")

# Verificar se os dados foram carregados
if df_localizacoes is None or modelo is None:
    st.error("ERRO: Arquivos de dados ('dataset_completo_com_clima.csv') ou do modelo não foram encontrados. Execute os notebooks de preparação.")
else:
    col1, col2 = st.columns(2)

    with col1:
        st.subheader("🌍 Seleção do Município")
        
        # Criar a lista de opções para o selectbox
        lista_municipios = df_localizacoes['display_name'].tolist()
        municipio_selecionado = st.selectbox(
            "Selecione o município",
            options=lista_municipios
        )
        
        # Encontrar as coordenadas correspondentes
        local_selecionado = df_localizacoes[df_localizacoes['display_name'] == municipio_selecionado].iloc[0]
        latitude = local_selecionado['latitude']
        longitude = local_selecionado['longitude']
        
        # Exibir as coordenadas encontradas (desabilitado para edição)
        st.text_input("Latitude", value=f"{latitude:.4f}", disabled=True)
        st.text_input("Longitude", value=f"{longitude:.4f}", disabled=True)

    with col2:
        st.subheader("🗓️ Período e Dados Ambientais")
        ano = st.slider("Ano da Safra para Previsão", min_value=2024, max_value=2030, value=2025)
        precipitacao = st.number_input("Precipitação Média Anual (mm/dia)", min_value=0.0, value=3.5, format="%.2f")
        temp_max = st.number_input("Temperatura Máxima Média Anual (°C)", min_value=20.0, value=32.0, format="%.2f")
        temp_min = st.number_input("Temperatura Mínima Média Anual (°C)", min_value=-5.0, value=20.0, format="%.2f")
        ndvi = st.number_input(
            "NDVI Máximo da Safra", min_value=0.0, max_value=1.0, value=0.75, format="%.4f",
            help="Índice de Vegetação por Diferença Normalizada - uma medida da saúde da vegetação."
        )

    # Botão para fazer a previsão
    if st.button("📊 Gerar Previsão", use_container_width=True):
        # Criar um DataFrame com os dados de entrada
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
