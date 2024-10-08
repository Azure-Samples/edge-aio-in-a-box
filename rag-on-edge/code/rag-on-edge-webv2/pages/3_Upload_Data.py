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

st.title('⬆️ Upload Data')
st.subheader('Upload PDF file for Azure Vector Search')

with st.spinner(text="Loading..."):
    backend_url = 'http://rag-vdb-service:8602/list_index_names'  
    index_names = requests.get(backend_url).json()['index_names']
    index_name = st.selectbox('Please select an index name.',index_names)
    st.write('You selected:', index_name)

uploaded_file = st.file_uploader("Please Choose a PDF file",type="pdf")
if uploaded_file is not None:
    # To read file as bytes:
    bytes_data = uploaded_file.getvalue()
    # Convert binary data to Base64-encoded string
    base64_data = base64.b64encode(bytes_data).decode('utf-8')

    with st.spinner(text="Document uploading..."):
        # Make an API call to Chroma backend to delete the index
        backend_url = 'http://rag-vdb-service:8602/upload_file'  # Replace with your actual backend URL
        payload = {'index_name': index_name, 'file_data': base64_data}
        response = requests.post(backend_url, json=payload)

        if response.status_code == 200:
            st.success(f"{response.json()['message']}")
        else:
            st.error(f"Failed to upload file. Error: {response.text}")

    st.success("done!")
    