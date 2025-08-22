import streamlit as st
import time

st.title("Teste de Conexão do App Runner")

st.write("Se você consegue ver esta mensagem, o deploy inicial funcionou.")

if st.button("Testar Interatividade (WebSocket)"):
    st.success("O WebSocket está a funcionar! O botão respondeu.")

st.write("Contador em tempo real:")
placeholder = st.empty()
for i in range(100):
    placeholder.text(f"Contagem: {i}")
    time.sleep(0.1)
