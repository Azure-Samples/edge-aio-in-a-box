# Use base image
FROM python:3.11

# Set the working directory
WORKDIR /app

# Install system dependencies in one step
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential libcurl4-openssl-dev libboost-python-dev libpython3-dev python3 python3-pip cmake curl git&& \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip and install required Python packages in one go
RUN pip3 install --upgrade pip setuptools ptvsd==4.1.3 python-dotenv streamlit

# Copy and install Python dependencies
COPY ./requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt

# Expose the required port
EXPOSE 8501

# Copy all files into the container
COPY . .

# Set the entry point to run the Streamlit app
ENTRYPOINT ["streamlit", "run", "RAG_On_Edge.py", "--server.port=8501", "--server.address=0.0.0.0"]