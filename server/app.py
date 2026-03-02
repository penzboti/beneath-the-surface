#!/usr/bin/env python3
"""
Lightweight leaderboard server for Pi Zero 2 W
Save scores and retrieve top times
"""

from flask import Flask, request, jsonify, abort
from flask_cors import CORS
import base64
import json
import os
from datetime import datetime
import fcntl

app = Flask(__name__)
# Enable CORS for all routes - works with itch.io, web builds, etc.
CORS(app, resources={
    r"/*": {
        "origins": "*",
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization", "X-Requested-With"],
        "max_age": 86400
    }
})

# Configuration
SCORES_FILE = "/var/lib/leaderboard/scores.json"
SECRET = "underwater_"
MAX_SCORES = 100

# Ensure scores directory exists
os.makedirs(os.path.dirname(SCORES_FILE), exist_ok=True)

def obscure(data):
    """Obscure data with base64 + prefix"""
    return base64.b64encode((SECRET + data).encode()).decode()

def reveal(data):
    """Reveal obscured data"""
    try:
        decoded = base64.b64decode(data).decode()
        if decoded.startswith(SECRET):
            return decoded[len(SECRET):]
    except:
        pass
    return None

def read_scores():
    """Thread-safe score reading with file locking"""
    if not os.path.exists(SCORES_FILE):
        return []

    try:
        with open(SCORES_FILE, 'r') as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_SH)
            data = json.load(f)
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
            return data
    except (json.JSONDecodeError, IOError):
        return []

def write_scores(scores):
    """Keep top 100 scores per level"""
    by_level = {}
    for s in scores:
        lvl = s.get('name', 'Unknown')
        if lvl not in by_level: by_level[lvl] = []
        by_level[lvl].append(s)

    new_scores = []
    for lvl in by_level:
        # Sort level scores by time (lower is better)
        by_level[lvl].sort(key=lambda x: x.get('time', 999999))
        new_scores.extend(by_level[lvl][:100])

    with open(SCORES_FILE + '.tmp', 'w') as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        json.dump(new_scores, f)
        f.flush()
        os.fsync(f.fileno())
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    os.rename(SCORES_FILE + '.tmp', SCORES_FILE)

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'service': 'leaderboard'})

@app.route('/submit', methods=['POST'])
def submit_score():
    """Submit a new score"""
    data = request.json
    if not data or 'data' not in data:
        return jsonify({'error': 'no data'}), 400

    # Rate limiting by IP could be added here

    revealed = reveal(data['data'])
    if not revealed:
        return jsonify({'error': 'invalid data'}), 400

    try:
        score_data = json.loads(revealed)

        # Validate required fields
        if 'name' not in score_data or 'time' not in score_data:
            return jsonify({'error': 'missing fields'}), 400

        # Sanitize name (max 20 chars, alphanumeric + spaces)
        name = ''.join(c for c in score_data['name'][:20] if c.isalnum() or c in ' _-')
        if not name:
            name = "Anonymous"

        score_data['name'] = name
        score_data['time'] = float(score_data['time'])
        score_data['date'] = datetime.utcnow().isoformat() + 'Z'

        scores = read_scores()
        scores.append(score_data)
        write_scores(scores)

        return jsonify({'success': True, 'rank': len([s for s in scores if s['time'] <= score_data['time']])})

    except (json.JSONDecodeError, ValueError, KeyError):
        return jsonify({'error': 'invalid score data'}), 400

@app.route('/scores', methods=['GET'])
def get_scores():
    """Get top scores"""
    limit = request.args.get('limit', 10, type=int)
    limit = min(limit, 50)  # Max 50

    scores = read_scores()
    return jsonify(scores[:limit])

@app.route('/')
@app.route('/leaderboard')
def leaderboard_html():
    """Simple HTML leaderboard view"""
    scores = read_scores()
    
    levels = {}
    for score in scores:
        lvl = score.get('name', 'Unknown')
        if lvl not in levels:
            levels[lvl] = []
        levels[lvl].append(score)

    html = """<!DOCTYPE html>
<html>
<head>
    <title>Leaderboard</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: monospace; max-width: 600px; margin: 20px auto; padding: 0 10px; }
        table { border-collapse: collapse; margin-bottom: 30px; width: 100%; }
        th, td { padding: 8px; border-bottom: 1px solid #ccc; text-align: left; }
    </style>
</head>
<body>
    <h1>Leaderboard</h1>
"""

    for lvl in sorted(levels.keys()):
        html += f"    <h2>{lvl}</h2>\n    <table>\n        <tr><th>#</th><th>Time</th><th>Date</th></tr>\n"
        lvl_scores = sorted(levels[lvl], key=lambda x: x.get('time', 999999))[:50]
        
        for i, score in enumerate(lvl_scores, 1):
            time = score.get('time', 0)
            date = score.get('date', '')
            html += f"        <tr><td>{i}</td><td>{time:.2f}s</td><td>{date}</td></tr>\n"
            
        html += "    </table>\n"

    html += """    <p><a href="/scores">JSON API</a></p>
</body>
</html>"""

    return html

@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'not found'}), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({'error': 'server error'}), 500

if __name__ == '__main__':
    # Run directly for testing
    app.run(host='127.0.0.1', port=5000, debug=False)
