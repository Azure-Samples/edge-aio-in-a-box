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

Login = "False"
st.title("👤 Log In")
st.caption("🚀 A Streamlit chatbot powered by Azure OpenAI")

def check_password():
    # """Returns `True` if the user had a correct password."""
    def password_entered(): 
        # """Checks whether a password entered by the user is correct."""
        if (
            # hardcode username and password here just for testing purpose, please remove it in production
            st.session_state["username001"] == "admin" and
            st.session_state["password001"] == "admin123456"
        ):
            del st.session_state["password"]  # don't store username + password
            del st.session_state["username"]
            return True
        else:
            return False

    st.session_state["username001"] = st.text_input("Username", key="username")
    st.session_state["password001"] = st.text_input("Password", type="password", key="password")
    if st.button("Login"):
        if password_entered():
            st.session_state.password_correct = True
            # st.experimental_rerun()
        else:
            st.error("😕 wrong username or password")
def init():
    with st.sidebar:
        st.title("Azure OpenAI Settings")
        # azure_openai_endpoint = st.text_input("Azure OpenAI Endpoint (i.e. https://YOURAISERVICE.openai.azure.com/)", key="chatbot_endpoint", type="default")
        # azure_openai_api_key = st.text_input("Azure OpenAI API Key", key="chatbot_api_key", type="password")
        "[Get an Azure OpenAI API key](https://platform.openai.com/account/api-keys)"
        "[View the source code](https://github.com/Azure-Samples/edge-aio-in-a-box/tree/main/rag-on-edge/code/rag-on-edge-web)"
        reset = st.sidebar.button("Reset Chat", on_click = clear_input)

def clear_input():
    st.session_state.pop("question", None)
    st.session_state.pop("messages", None)
    st.session_state.selected_question = ""

def main():
    if Login == "False":
        if "password_correct" not in st.session_state:
            st.session_state.password_correct = False
        if not st.session_state["password_correct"]:
            check_password()
        else:
            init()
    else:
        init()

if __name__ == "__main__":
    main()