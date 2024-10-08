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
st.subheader('Create Index')

index_name = st.text_input('Please input index name')

if st.button('Create Index') or index_name != '':
    if index_name == '':
        st.error('Please input index name!')
        st.stop()
    else:
        with st.spinner('Creating index...'):
            # Make an API call to Chroma backend to delete the index
            backend_url = 'http://rag-vdb-service:8602/create_index'
            payload = {'index_name': index_name}
            response = requests.post(backend_url, json=payload)

            if response.status_code == 200:
                st.success("Index created successfully!")
            else:
                st.error(f"Failed to create index. Error: {response.text}")