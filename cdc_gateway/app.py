from flask import Flask, request, jsonify
import os
import subprocess
import hashlib
import shutil
from pathlib import Path
import logging
from datetime import datetime

app = Flask(__name__)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

YAML_DIR = "/shared/cdc-yaml"
FLINK_CDC_SH = "/opt/flink/bin/flink-cdc.sh"
JOBMANAGER_CONTAINER = "jobmanager"

os.makedirs(YAML_DIR, exist_ok=True)


def generate_hash(content: str) -> str:
    return hashlib.md5(content.encode()).hexdigest()[:16]


def execute_on_jobmanager(command: list) -> tuple:
    try:
        full_command = ["docker", "exec", JOBMANAGER_CONTAINER] + command
        result = subprocess.run(
            full_command, capture_output=True, text=True, timeout=300
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "flink-cdc-gateway"}), 200


@app.route("/submit", methods=["POST"])
def submit_cdc_job():
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "No file selected"}), 400

    if not file.filename.endswith((".yaml", ".yml")):
        return jsonify({"error": "Only YAML files are supported"}), 400

    content = file.read().decode("utf-8")
    file_hash = generate_hash(content)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"cdc_{timestamp}_{file_hash}.yaml"
    filepath = os.path.join(YAML_DIR, filename)

    try:
        with open(filepath, "w") as f:
            f.write(content)

        logger.info(f"Saved YAML file: {filename}")

        returncode, stdout, stderr = execute_on_jobmanager([FLINK_CDC_SH, filepath])

        if returncode != 0:
            logger.error(f"Flink CDC failed: {stderr}")
            return jsonify(
                {
                    "error": "Failed to execute Flink CDC",
                    "details": stderr,
                    "stdout": stdout,
                }
            ), 500

        job_id = None
        for line in stdout.split("\n"):
            if "Job has been submitted" in line or "Job ID" in line:
                parts = line.split()
                for i, part in enumerate(parts):
                    if part.replace(".", "").isdigit():
                        job_id = part
                        break

        logger.info(f"Flink CDC job submitted: {filename} (Job ID: {job_id})")

        return jsonify(
            {
                "status": "submitted",
                "filename": filename,
                "job_id": job_id,
                "message": "CDC job submitted successfully",
                "stdout": stdout,
            }
        ), 200

    except Exception as e:
        logger.error(f"Error submitting CDC job: {str(e)}")
        return jsonify({"error": str(e)}), 500


@app.route("/jobs", methods=["GET"])
def list_jobs():
    try:
        files = []
        for filepath in Path(YAML_DIR).glob("*.yaml"):
            stat = filepath.stat()
            files.append(
                {
                    "filename": filepath.name,
                    "size": stat.st_size,
                    "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                }
            )

        return jsonify({"jobs": files}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/jobs/<filename>", methods=["DELETE"])
def delete_job(filename):
    filepath = os.path.join(YAML_DIR, filename)

    if not os.path.exists(filepath):
        return jsonify({"error": "File not found"}), 404

    try:
        os.remove(filepath)
        logger.info(f"Deleted YAML file: {filename}")
        return jsonify({"status": "deleted", "filename": filename}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
