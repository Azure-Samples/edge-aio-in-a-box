# Use base image
FROM python:3.11

# Set the working directory
WORKDIR /app

# Install system dependencies in one step
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential libcurl4-openssl-dev libboost-python-dev libpython3-dev python3 python3-pip cmake curl git&& \
    rm -rf /var/lib/apt/lists/*
RUN pip3 install --upgrade pip
RUN pip3 install setuptools
RUN pip3 install ptvsd==4.1.3

# Copy and install Python dependencies
COPY ./requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt
RUN pip3 install python-dotenv==0.21.0

# Expose the required port
EXPOSE 8501

# Copy all files into the container
COPY . .

# Set the entry point to run the Streamlit app
ENTRYPOINT ["streamlit", "run", "page_home.py", "--server.port=8501", "--server.address=0.0.0.0"]
