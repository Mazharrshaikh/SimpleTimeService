from datetime import datetime, timezone
from flask import Flask, request, Response 
import json

app = Flask(__name__)

def get_client_ip():
    # Check for X-Forwarded-For header, common when behind a proxy/load balancer
    xff = request.headers.get("X-Forwarded-For", "")
    if xff:
        # If present, return the first IP in the list (the original client)
        return xff.split(",")[0].strip()
    # Fallback: return the direct connecting IP address
    return request.remote_addr

@app.route("/", methods=["GET"])
def root():
    now = datetime.now(timezone.utc).isoformat()
    ip = get_client_ip()
    
    
    payload = {"timestamp": now, "ip": ip} 

    json_string = json.dumps(
        payload, 
        sort_keys=False # Prevents alphabetical sorting
    )
    
    
    return Response(json_string, mimetype='application/json')
