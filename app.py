import streamlit as st
import pandas as pd
import joblib
import numpy as np

# --- Configuração da Página ---
st.set_page_config(
    page_title="AvatiVision - Previsão de Safras",
    page_icon="🌽",
    layout="wide"
)

# --- Funções de Carregamento de Dados (com cache) ---

@st.cache_resource
def carregar_modelo():
    """Carrega o modelo treinado do arquivo."""
    try:
        modelo = joblib.load('models/avativision_random_forest_v1.joblib')
        return modelo
    except FileNotFoundError:
        return None

@st.cache_data
def carregar_dados_localizacao():
    """Carrega o ficheiro de localizações otimizado para um arranque rápido."""
    try:
        # Usando o ficheiro de localizações otimizado para a UI (levemente otimizado) 
        caminho_dados = 'data/processed/locations.parquet'
        df = pd.read_parquet(caminho_dados)
        df['display_name'] = df['municipio_nome'] + ' (' + df['uf'] + ')'
        return df
    except FileNotFoundError:
        return None

# --- Carregamento Inicial ---
modelo = carregar_modelo()
df_localizacoes = carregar_dados_localizacao()

# --- Interface do Usuário (UI) ---
st.title("🌽 AvatiVision: Sistema de Previsão de Produtividade de Milho")
st.markdown("Selecione o município e insira os dados da safra para obter uma previsão de rendimento.")

# Verificar se os dados foram carregados
if df_localizacoes is None or modelo is None:
    st.error("ERRO: Arquivos de dados ('locations.parquet') ou do modelo não foram encontrados. Execute os notebooks de preparação.")
else:
    col1, col2 = st.columns(2)

    with col1:
        st.subheader("🌍 Seleção do Município")
        
        lista_municipios = df_localizacoes['display_name'].tolist()
        municipio_selecionado = st.selectbox(
            "Selecione o município",
            options=lista_municipios
        )
        
        local_selecionado = df_localizacoes[df_localizacoes['display_name'] == municipio_selecionado].iloc[0]
        latitude = local_selecionado['latitude']
        longitude = local_selecionado['longitude']
        
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

    # Botão para prever
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
        
        # resultado
        st.success("### Previsão de Rendimento Gerada!")
        st.metric(
            label="Rendimento Médio Estimado",
            value=f"{previsao[0]:.2f} kg/ha",
            help="Esta é a previsão da produtividade em quilogramas por hectare."
        )
