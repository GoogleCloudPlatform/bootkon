## Lab 4: ML Operations

<walkthrough-tutorial-duration duration="60"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="3"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>
{% set TRAIN_IMAGE_URI = "{}-docker.pkg.dev/{}/bootkon/bootkon-train:latest".format(REGION, PROJECT_ID) %}
{% set PREDICT_IMAGE_URI = "{}-docker.pkg.dev/{}/bootkon/bootkon-predict:latest".format(REGION, PROJECT_ID) %}
{% set BQ_SOURCE = "{}.ml_datasets.ulb_fraud_detection_dataproc".format(PROJECT_ID) %}

In this lab, we will build a machine learning model to assess, in real-time, whether incoming transactions are fraudulent or legitimate. Using Agent Platform Pipelines (based on Kubeflow), we will streamline the end-to-end ML workflow, from data preprocessing to model deployment, ensuring scalability and efficiency in fraud detection.

In Agent Platform, custom containers allow you to define and package your own execution environment for machine learning workflows. To store custom container images, create a repository in artifact registry:

```bash
gcloud artifacts repositories create bootkon --repository-format=docker --location={{ REGION }}
```

Let us create two container images, one for training and one for serving predictions.

The training container is comprised of the following files. Please have a look at them:
- <walkthrough-editor-open-file filePath="content/data/src/ml/train/Dockerfile">`train/Dockerfile`</walkthrough-editor-open-file>: Executes the training script.
- <walkthrough-editor-open-file filePath="content/data/src/ml/train/train.py">`train/train.py`</walkthrough-editor-open-file>: Downloads the data set from BigQuery, trains a machine learning model, and uploads the model to Cloud Storage.

The serving container image is comprised of the following files:
- <walkthrough-editor-open-file filePath="content/data/src/ml/predict/Dockerfile">`predict/Dockerfile`</walkthrough-editor-open-file>: Executes the serving script to answer requests.
- <walkthrough-editor-open-file filePath="content/data/src/ml/predict/predict.py">`predict/predict.py`</walkthrough-editor-open-file>: Downloads the model from Cloud Storage, loads it, and answers predictions on port `8080`.

We can create the container images using Cloud Build, which allows you to build a Docker image using just a Dockerfile. The next command builds the image in Cloud Build and pushes it to Artifact Registry:

```bash
(cd content/data/src/ml/train && gcloud builds submit --region={{ REGION }} --tag={{ TRAIN_IMAGE_URI }} --quiet)
```

Let's do the same for the serving image:

```bash
(cd content/data/src/ml/predict && gcloud builds submit --region={{ REGION }} --tag={{ PREDICT_IMAGE_URI }} --quiet)
```

### Agent Platform Pipelines

Now, have a look at <walkthrough-editor-open-file filePath="content/data/src/ml/pipeline.py">`pipeline.py`</walkthrough-editor-open-file>. This script uses the Kubeflow domain specific language (dsl) to orchestrate the following machine learning workflow:

1. `CustomTrainingJobOp` trains the model.
2. `ModelUploadOp` uploads the trained model to the Agent Platform model registry.
3. `EndpointCreateOp` creates a prediction endpoint for inference.
4. `ModelDeployOp` deploys the model from step 2 to the endpoint from step 3.

Let's execute it:

```bash
python content/data/src/ml/pipeline.py
```

The pipeline run will take around 20 minutes to complete. While waiting, please read the introduction to [Agent Platform Pipelines](https://docs.cloud.google.com/vertex-ai/docs/pipelines/introduction).

### Custom Training Job

The pipeline creates a custom training job -- let's inspect it in the Cloud Console once it has completed:

1. Open [Vertex AI Console](https://console.cloud.google.com/vertex-ai)
2. Click <walkthrough-spotlight-pointer locator="css(a[id$=cfctest-section-nav-item-ai-platform-training])">Training</walkthrough-spotlight-pointer> in the navigation menu
3. Click <walkthrough-spotlight-pointer locator="semantic({tab 'Custom jobs'})">Custom jobs</walkthrough-spotlight-pointer>
4. Click <walkthrough-spotlight-pointer locator="semantic({link 'bootkon-training-job'})">bootkon-training-job</walkthrough-spotlight-pointer>

Note the container image it uses and the arguments that are passed to the container (dataset in BigQuery and project id).

### Model Registry

Once the training job has finished, the resulting model is uploaded to the model registry. Let's have a look:

1. Click <walkthrough-spotlight-pointer locator="css(a[id$=cfctest-section-nav-item-ai-platform-models])">Model Registry</walkthrough-spotlight-pointer> in the nevigation menu
2. Click <walkthrough-spotlight-pointer locator="semantic({link 'bootkon-model'})">bootkon-model</walkthrough-spotlight-pointer>
3. Click <walkthrough-spotlight-pointer locator="semantic({tab 'Version details'})">VERSION DETAILS</walkthrough-spotlight-pointer>

Here you can can see that a model in the Vertex AI Model Registry is made up from a **Container image** as well as a **Model artifact location**. When you deploy a model, Vertex AI simply starts the container and points it to the artifact location.

### Endpoint for Predictions

The endpoint is created in a parallel branch in the pipeline you just ran. You can deploy models to an endpoint through the model registry.

1. Click <walkthrough-spotlight-pointer locator="css(a[id$=cfctest-section-nav-item-ai-platform-online-prediction])">Endpoints</walkthrough-spotlight-pointer> in the navigation menu
2. Click <walkthrough-spotlight-pointer locator="semantic({link 'bootkon-endpoint'})">bootkon-endpoint</walkthrough-spotlight-pointer>

You can see that the endpoint has one model deployed currently, and all the traffic is routed to it (traffic split is 100%). When scrolling down, you get live graphs as soon as predictions are coming in.

You can also train and deploy models on Vertex in the UI only. Let's have a more detailed look. Click <walkthrough-spotlight-pointer locator="semantic({button 'Edit settings'})">Edit Settings</walkthrough-spotlight-pointer>. Here you can find many options for model monitoring -- why don't you try to enable prediction drift detection?

### Vertex AI Pipelines

Let's have a look at the Pipeline as well.

1. Click <walkthrough-spotlight-pointer locator="css(a[aria-label$=Pipelines])">Pipelines</walkthrough-spotlight-pointer> in the navigation menu
2. Click <walkthrough-spotlight-pointer locator='semantic({link "bootkon-pipeline-*"})'>bootkon-pipeline-...</walkthrough-spotlight-pointer>

You can now see the individual steps in the pipeline. Please click through the individual steps of the pipeline and have a look at the *Pipeline run analysis* on the right hand side as you cycle pipeline steps. 

Click on *Expand Artifacts*. Now, you can see expanded yellow boxes. These are Vertex AI artifacts that are created as a result of the previous step.

Feel free to explore the UI in more detail on your own!

### Making predictions

Now that the endpoint has been deployed, we can send transactions to it to assess whether they are fraudulent or not.
We can use `curl` to send transactions to the endpoint. 

Have a look at <walkthrough-editor-open-file filePath="content/data/src/ml/predict.sh">`predict.sh`</walkthrough-editor-open-file>. In line 9 it uses `curl` to call the endpoint using a data file named  <walkthrough-editor-open-file filePath="content/data/src/ml/instances.json">`instances.json`</walkthrough-editor-open-file> containing 3 transactions.

Let's execute it:

```bash
content/data/src/ml/predict.sh
```

The result should be a JSON object with a `prediction` key, containing the predictions for each of the 3 transactions. `1` means fraud and `0` means non-fraud.

### Success

Congratulations, intrepid ML explorer{% if MY_NAME %} {{ MY_NAME }}{% endif %}! 🚀 You've successfully wrangled data, trained models, and unleashed the power of Vertex AI. If your model underperforms, remember: it's not a bug—it's just an underfitting feature! Keep iterating, keep optimizing, and may your loss functions always converge. Happy coding! 🤖✨

