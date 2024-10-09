import streamlit as st
from llmware.models import ModelCatalog
from llmware.gguf_configs import GGUFConfigs

GGUFConfigs().set_config("max_output_tokens", 500)


def simple_chat_ui_app (model_name):

    st.title(f"Simple Chat with {model_name}")

    model = ModelCatalog().load_model(model_name, temperature=0.3, sample=True, max_output=450)

    if "messages" not in st.session_state:
        st.session_state.messages = []

    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    prompt = st.chat_input("Say something")
    if prompt:

        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):

            bot_response = st.write_stream(model.stream(prompt))

        st.session_state.messages.append({"role": "user", "content": prompt})
        st.session_state.messages.append({"role": "assistant", "content": bot_response})

    return 0


if __name__ == "__main__":

    chat_models = ["phi-3-gguf",
                   "llama-2-7b-chat-gguf",
                   "llama-3-instruct-bartowski-gguf",
                   "openhermes-mistral-7b-gguf",
                   "zephyr-7b-gguf",
                   "tiny-llama-chat-gguf"]

    model_name = chat_models[0]

    simple_chat_ui_app(model_name)