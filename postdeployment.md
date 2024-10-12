# Post deployemnt

Once your resources have been deployed you will need to do the following to get the notebook(s) up running in Azure ML Studio and your Edge Kubernetes Pod to see the solution flows:

* When running the notebooks in AML your user (jim@contoso.com for instance) won't have permission to alter the storage account or add data to the storage. Please ensure that you have been assigned both **Storage Blob Data Reader** and **Storage Blob Data Contributor** roles.

* Run the Notebook(s) 
    * ***[1-Img-Classification-Training.ipynb](/notebooks/1-Img-Classification-Training.ipynb)***
    * This notebook has been automatically uploaded to a folder named EdgeAI within your Azure ML workspace. Its purpose is to guide you through building a custom model in Azure ML, registering the model, and deploying it to a container or endpoint in your Arc-enabled Kubernetes cluster using the Azure ML Extension. Additionally, you can test the endpoint using a Postman collection available in the postman folder within the repository.

* Testing Locally with PostMan
    * At the end of the notebook, you'll find instructions on how to use Postman to test, ping, and query the K3s/AIO endpoint.
    * The [notebook](/notebooks/1-Img-Classification-Training.ipynb) has instructions on how you can setup port forwarding, 
    
    ### Postman: sklearn mnist model testing through Port Forwarding
    ![Postman: sklearn mnist model testing through Port Forwarding](/readme_assets/postman-sklearn_mnist_model-portforwarding.png) 
    
    ### Postman: sklearn mnist model testing through VM Public IP
    ![Postman: sklearn mnist model testing through VM Public IP](/readme_assets/postman-sklearn_mnist_model-portforwarding.png) 
    
