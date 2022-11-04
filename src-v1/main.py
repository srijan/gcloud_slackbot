import functions_framework
from slack_bolt import App

# process_before_response must be True when running on FaaS
app = App(process_before_response=True)

print('Function has started')

@functions_framework.http
def send_to_slack(request):
    print('send_to_slack triggered')
    channel = '#general'
    text = 'Hello from Google Cloud Functions!'
    app.client.chat_postMessage(channel=channel, text=text)
    return 'Sent to slack!'
