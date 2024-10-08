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

# LangChain imports
from langchain.agents import initialize_agent, AgentType
from langchain.callbacks import StreamlitCallbackHandler
from langchain.chat_models import AzureChatOpenAI
from langchain.tools import DuckDuckGoSearchRun

# Load variables from .env file
load_dotenv()

st.title("🔎 Chatbot with LangChain")
st.caption("🚀 A chatbot powered by Azure OpenAI and LangChain")

def clear_input():
    st.session_state.pop("question", None)
    st.session_state.pop("messages", None)
    st.session_state.selected_question = ""

with st.sidebar:
    st.title("Azure OpenAI Settings")
    azure_openai_endpoint = st.text_input("Azure OpenAI Endpoint (i.e. https://YOURAISERVICE.openai.azure.com/)", key="chatbot_endpoint", type="default")
    azure_openai_api_key = st.text_input("Azure OpenAI API Key", key="chatbot_api_key", type="password")
    "[Get an Azure OpenAI API key](https://learn.microsoft.com/en-us/azure/ai-services/openai/chatgpt-quickstart)"

    reset = st.sidebar.button("Reset Chat", on_click = clear_input)

"""
In this example, we're using `StreamlitCallbackHandler` to display the thoughts and actions of an agent in an interactive Streamlit app.
Try more LangChain 🤝 Streamlit Agent examples at [github.com/langchain-ai/streamlit-agent](https://github.com/langchain-ai/streamlit-agent).
"""

if "messages" not in st.session_state:
    st.session_state["messages"] = [{"role": "assistant", "content": "Hi, I'm a chatbot who can search the web. How can I help you?"}]

for msg in st.session_state.messages:
    st.chat_message(msg["role"]).write(msg["content"])

if prompt := st.chat_input(placeholder="Who won the Women's U.S. Open in 2018?"):
    st.session_state.messages.append({"role": "user", "content": prompt})
    st.chat_message("user").write(prompt)

    if not azure_openai_api_key and not azure_openai_endpoint:
        st.info("Please add both your Azure OpenAI API key and Azure OpenAI Endpoint to continue.")
        st.stop()
    elif not azure_openai_api_key:
        st.info("Please add your Azure OpenAI API key to continue.")
        st.stop()
    elif not azure_openai_endpoint:
        st.info("Please add your Azure OpenAI Endpoint to continue.")
        st.stop()

    client = AzureChatOpenAI(
        deployment_name="gpt-35-turbo",  
        api_key=azure_openai_api_key,
        api_version="2024-02-01",
        azure_endpoint=azure_openai_endpoint,
        streaming=True
    )

    search = DuckDuckGoSearchRun(name="Search")
    search_agent = initialize_agent(
        [search], client, agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION, handle_parsing_errors=True
    )
    with st.chat_message("assistant"):
        st_cb = StreamlitCallbackHandler(st.container(), expand_new_thoughts=False)
        response = search_agent.run(st.session_state.messages, callbacks=[st_cb])
        st.session_state.messages.append({"role": "assistant", "content": response})
        st.write(response)
