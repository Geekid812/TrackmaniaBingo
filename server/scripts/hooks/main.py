# /// script
# dependencies = [
#   "requests",
#   "flask",
# ]
# ///

import flask
import sys
import requests

app = flask.Flask(__name__)

@app.route('/', methods=['POST'])
def forward_request():
    target_url = sys.argv[3]
    auth_token = sys.argv[4]
    if len(sys.argv) > 5:
        matchexp = sys.argv[5]
        mjson = flask.request.get_json(force=True)
        if matchexp.lower() not in mjson["room_config"]["name"].lower():
            return flask.Response(status=204)

    try:
        response = requests.post(
            target_url,
            data=flask.request.get_data(),
            headers={'X-AUTH-TOKEN': auth_token},
            timeout=10
        )
        return flask.Response(status=response.status_code)
    except Exception as e:
        return flask.jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Usage: main.py <host> <port> <target_url> <auth_token> [matchexp]")
        sys.exit(1)
    
    host = sys.argv[1]
    port = int(sys.argv[2])
    app.run(host=host, port=port, debug=False)
