import base64
import json
import time
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
        max_days = event_data["max_days"] # Max age of channels
        channel = event_data["channel"]
        recent_channels = get_recent_channels(app, max_days)
        if len(recent_channels) > 0:
            blocks, text = format_channels(recent_channels, max_days)
            app.client.chat_postMessage(channel=channel, text=text,
                                        blocks=blocks)
        else:
            print("No recent channels")
    except Exception as E:
        print("Error decoding message: %s" % E)


def get_recent_channels(app, max_days):
    max_age_s = max_days * 24 * 60 * 60
    result = app.client.conversations_list()
    all = result["channels"]
    now = time.time()
    return [ c for c in all if (now - c["created"] <= max_age_s) ]

def format_channels(channels, max_days):
    text = ("%s channels created in the last %s day(s):" %
            (len(channels), max_days))
    blocks = [{
        "type": "header",
        "text": {
            "type": "plain_text",
            "text": text
        }
    }]
    summary = ""
    for c in channels:
        summary += "\n*<#%s>*: %s" % (c["id"], c["purpose"]["value"])
    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": summary
        }
    })
    return blocks, text
