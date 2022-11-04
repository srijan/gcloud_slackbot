# Variables
-include env
ifndef PROJECT_ID
$(error PROJECT_ID is not set. Run `cp env.sample env` and edit it as required.)
endif

REGION   ?= us-central1
SA_NAME  ?= channelbot-sa
SA_EMAIL  = $(SA_NAME)@$(PROJECT_ID).iam.gserviceaccount.com

.PHONY: all

all:
	true

project:
	gcloud projects create $(PROJECT_ID) || true
	gcloud services enable --project $(PROJECT_ID) \
	    secretmanager.googleapis.com \
	    cloudfunctions.googleapis.com \
	    run.googleapis.com \
	    cloudbuild.googleapis.com \
	    artifactregistry.googleapis.com \
	    logging.googleapis.com

project-delete:
	gcloud projects delete $(PROJECT_ID)

service-account:
	gcloud iam service-accounts create $(SA_NAME) \
	    --project=$(PROJECT_ID) \
		--description="Service Account for ChannelBot slackbot" \
		--display-name="ChannelBot SlackBot SA"

delete-service-account:
	gcloud iam service-accounts delete $(SA_EMAIL)

list-secrets:
	gcloud secrets list --project=${PROJECT_ID}

create-secrets:
	@read -p "Bot User OAuth Token: " SLACK_BOT_TOKEN; \
	read -p "Signing Secret: " SLACK_SIGNING_SECRET; \
	printf $${SLACK_BOT_TOKEN} | gcloud secrets create \
	    channelbot-slack-bot-token --data-file=- \
	    --project=$(PROJECT_ID) \
	    --replication-policy=user-managed \
	    --locations=$(REGION) ; \
	printf $${SLACK_SIGNING_SECRET} | gcloud secrets create \
	    channelbot-slack-signing-secret --data-file=- \
	    --project=$(PROJECT_ID) \
	    --replication-policy=user-managed \
	    --locations=$(REGION)

secrets-access:
	gcloud secrets add-iam-policy-binding \
        projects/$(PROJECT_ID)/secrets/channelbot-slack-bot-token \
        --member serviceAccount:$(SA_EMAIL) \
        --role roles/secretmanager.secretAccessor
	gcloud secrets add-iam-policy-binding \
	    projects/$(PROJECT_ID)/secrets/channelbot-slack-signing-secret \
	    --member serviceAccount:$(SA_EMAIL) \
	    --role roles/secretmanager.secretAccessor

deploy-function-v1:
	gcloud beta functions deploy channelbot-send-to-slack \
	    --gen2 \
	    --runtime python310 \
	    --project=$(PROJECT_ID) \
	    --service-account=$(SA_EMAIL) \
	    --source ./src-v1 \
	    --entry-point send_to_slack \
	    --trigger-http \
	    --allow-unauthenticated \
	    --region $(REGION) \
	    --memory=128MiB \
	    --min-instances=0 \
	    --max-instances=1 \
	    --set-secrets \
	      'SLACK_BOT_TOKEN=channelbot-slack-bot-token:latest,\
	       SLACK_SIGNING_SECRET=channelbot-slack-signing-secret:latest' \
	    --timeout 60s

function-logs:
	gcloud beta functions logs read channelbot-send-to-slack \
		--project $(PROJECT_ID) --gen2

delete-function:
	gcloud beta functions delete channelbot-send-to-slack \
		--project $(PROJECT_ID) --region $(REGION) --gen2
