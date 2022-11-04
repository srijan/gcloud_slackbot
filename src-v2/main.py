import base64
import json
import functions_framework
from slack_bolt import App

# process_before_response must be True when running on FaaS
app = App(process_before_response=True)

print('Function has started')

# Triggered from a message on a Cloud Pub/Sub topic.
@functions_framework.cloud_event
def pubsub_handler(cloud_event):
    try:
        data = base64.b64decode(
            cloud_event.data["message"]["data"]).decode()
        print("Received from pub/sub: %s" % data)
        event_data = json.loads(data)
        channel = event_data["channel"]
        text = event_data["text"]
        app.client.chat_postMessage(channel=channel, text=text)
    except Exception as E:
        print("Error decoding message: %s" % E)
