import json
import os
import subprocess
import hashlib
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

from berean_prompt import BEREAN_SYSTEM_PROMPT

app = Flask(__name__)
CORS(app)
limiter = Limiter(get_remote_address, app=app, default_limits=[])

STATE_DIR = os.path.expanduser("~/the-berean/state")
QA_LOG = os.path.join(STATE_DIR, "qa-log.json")

os.makedirs(STATE_DIR, exist_ok=True)


def load_qa_log():
    if os.path.exists(QA_LOG):
        with open(QA_LOG, "r") as f:
            data = json.load(f)
            # Handle both list and dict formats
            if isinstance(data, dict):
                return data.get("questions", [])
            return data
    return []


def save_qa_log(log):
    with open(QA_LOG, "w") as f:
        json.dump(log, f, indent=2)


def ask_claude(question):
    """Call Claude Code CLI with The Berean's prompt."""
    full_prompt = f"{BEREAN_SYSTEM_PROMPT}\n\nQuestion: {question}\n\nAnswer faithfully and succinctly."
    result = subprocess.run(
        ["claude", "--print", "--max-turns", "1", "-p", full_prompt],
        capture_output=True,
        text=True,
        timeout=120,
        env={**os.environ}
    )
    if result.returncode != 0:
        raise RuntimeError(f"Claude CLI error: {result.stderr}")
    return result.stdout.strip()


@app.route("/api/ask", methods=["POST"])
@limiter.limit("10 per hour")
def ask():
    data = request.get_json()
    question = data.get("question", "").strip()
    if not question:
        return jsonify({"error": "Please ask a question."}), 400
    if len(question) > 500:
        return jsonify({"error": "Question too long. Please keep it under 500 characters."}), 400

    try:
        answer = ask_claude(question)
    except Exception as e:
        return jsonify({"error": "The Berean is momentarily unable to respond. Please try again shortly."}), 503

    # Log Q&A
    ip_hash = hashlib.sha256(request.remote_addr.encode()).hexdigest()[:12]
    log = load_qa_log()
    log.append({
        "question": question,
        "answer": answer,
        "timestamp": datetime.utcnow().isoformat(),
        "ip_hash": ip_hash
    })
    save_qa_log(log)

    return jsonify({"answer": answer})


@app.route("/api/recent", methods=["GET"])
def recent():
    """Return recent Q&As for display on the ask page."""
    log = load_qa_log()
    # Return last 10, newest first, without IP hashes
    recent_qas = [
        {"question": entry["question"], "answer": entry["answer"], "timestamp": entry.get("timestamp", "")}
        for entry in reversed(log[-10:])
    ]
    return jsonify({"questions": recent_qas})


@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "name": "The Berean"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
