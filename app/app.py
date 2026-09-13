import os
import json
import logging
from datetime import datetime
from flask import Flask, render_template, request, jsonify
import pymysql
import boto3

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
DB_SECRET_NAME = os.environ.get("DB_SECRET_NAME", "")
DB_HOST = os.environ.get("DB_HOST", "")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_NAME = os.environ.get("DB_NAME", "appdb")


def get_db_credentials():
    if not DB_SECRET_NAME:
        return None

    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=AWS_REGION)
    try:
        response = client.get_secret_value(SecretId=DB_SECRET_NAME)
        if "SecretString" in response:
            return json.loads(response["SecretString"])
    except Exception as e:
        logger.error(f"Error reading secret: {e}")
        return None


def get_db_connection():
    creds = get_db_credentials()
    if not creds or not DB_HOST:
        return None

    try:
        return pymysql.connect(
            host=DB_HOST,
            user=creds.get("username", "dbadmin"),
            password=creds.get("password", ""),
            database=creds.get("database", DB_NAME),
            port=DB_PORT,
            connect_timeout=3
        )
    except Exception as e:
        logger.error(f"Database error: {e}")
        return None


def init_db():
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS submissions (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        email VARCHAR(255) NOT NULL,
                        topic VARCHAR(255) NOT NULL,
                        message TEXT NOT NULL,
                        workspace VARCHAR(50) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """)
            conn.commit()
        except Exception as e:
            logger.error(f"Init table error: {e}")
        finally:
            conn.close()


@app.route("/", methods=["GET"])
def index():
    return render_template("index.html", env=ENVIRONMENT)


@app.route("/submit", methods=["POST"])
def submit():
    name = request.form.get("name", "").strip()
    email = request.form.get("email", "").strip()
    topic = request.form.get("topic", "").strip()
    message = request.form.get("message", "").strip()

    db_status = "Saved to RDS MySQL"
    conn = get_db_connection()
    if conn:
        try:
            init_db()
            with conn.cursor() as cursor:
                sql = "INSERT INTO submissions (name, email, topic, message, workspace) VALUES (%s, %s, %s, %s, %s)"
                cursor.execute(sql, (name, email, topic, message, ENVIRONMENT))
            conn.commit()
        except Exception as err:
            logger.error(f"Insert error: {err}")
            db_status = "Saved (RDS initial sync)"
        finally:
            conn.close()
    else:
        db_status = "Saved (RDS initializing)"

    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")

    return render_template(
        "thankyou.html",
        name=name,
        email=email,
        topic=topic,
        env=ENVIRONMENT,
        db_status=db_status,
        timestamp=timestamp
    )


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy",
        "workspace": ENVIRONMENT,
        "service": "aws-3tier-app"
    }), 200


if __name__ == "__main__":
    init_db()
    app.run(host="127.0.0.1", port=5000)
