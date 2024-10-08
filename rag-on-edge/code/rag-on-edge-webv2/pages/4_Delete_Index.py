# Standard library imports
import os
import time
import base64

# Third-party imports
import requests
import yaml
import streamlit as st
from dotenv import load_dotenv

# Azure OpenAI import
from openai import AzureOpenAI

# Load variables from .env file
load_dotenv()

st.title("🛠️ Index Management")
st.subheader('Delete Index')

# Fetch index names from Chroma backend
backend_url = 'http://rag-vdb-service:8602/list_index_names'  
index_names = requests.get(backend_url).json()['index_names']

with st.spinner(text="Loading..."):
    st.session_state.item = None
    selected_index_name = st.selectbox('Please select an index name.',index_names,index=st.session_state.item)

if st.button('Delete Index'):
    if selected_index_name == None:
        st.stop()
    else:
        with st.spinner('Deleting index...'):
            # Make an API call to Chroma backend to delete the index
            backend_url = 'http://rag-vdb-service:8602/delete_index'  
            payload = {'index_name': selected_index_name}
            response = requests.post(backend_url, json=payload)

            if response.status_code == 200:
                st.session_state.item = None
                st.rerun()
                st.success("Index deleted successfully!")
            else:
                st.error(f"Failed to delete index. Error: {response.text}")