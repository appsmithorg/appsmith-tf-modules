## How to start Appsmith with Cloud Run

This terraform file expects a credentials.json file with a JSON service account key to exist next to the main.tf that has access to the GCP project you are intending to deploy Appsmith. 

To deploy appsmith you will be prompted by certain variables, like your GCP project id, region, zone and your MongoDB URI. 



## Initializing the module
```
terraform init
```