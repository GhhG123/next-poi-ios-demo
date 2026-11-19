"""Local demo API for the Next POI iOS project."""

from contextlib import closing
import json
from pathlib import Path
import sqlite3

from flask import Flask, jsonify, request


ROOT = Path(__file__).resolve().parent
FIXTURE = ROOT.parent / "ios" / "NextPOI" / "Resources" / "DemoData.json"


def seed_database(database, trips):
    database.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(database)) as connection, connection:
        connection.execute("""
            CREATE TABLE IF NOT EXISTS check_ins (
                trip_id INTEGER NOT NULL,
                position INTEGER NOT NULL,
                venueid INTEGER NOT NULL,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                city TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                timestamp TEXT NOT NULL,
                PRIMARY KEY (trip_id, position)
            )
        """)
        connection.execute("DELETE FROM check_ins")
        connection.executemany("""
            INSERT INTO check_ins
                (trip_id, position, venueid, name, category, city, latitude, longitude, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            (trip["id"], position, record["venueid"], record["name"], record["category"],
             record["city"], record["latitude"], record["longitude"], record["timestamp"])
            for trip in trips
            for position, record in enumerate(trip["check_ins"])
        ))


def create_app(database=None):
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 4096
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    trips = {trip["id"]: trip for trip in fixture["trips"]}
    database = Path(database) if database is not None else ROOT / "instance" / "demo.sqlite3"
    seed_database(database, trips.values())

    def demo_input():
        payload = request.get_json(silent=True)
        if not isinstance(payload, dict) or type(payload.get("user_id")) is not int:
            return None, (jsonify(error="user_id must be an integer"), 400)
        if payload["user_id"] != fixture["user_id"]:
            return None, (jsonify(error="demo user not found"), 404)
        return payload, None

    @app.route("/health")
    def health():
        return jsonify(status="ok", mode="demo")

    @app.route("/get_records", methods=["POST"])
    def records():
        _, error = demo_input()
        if error:
            return error
        with closing(sqlite3.connect(database)) as connection:
            connection.row_factory = sqlite3.Row
            rows = connection.execute("""
                SELECT trip_id, venueid, name, category, city, latitude, longitude, timestamp
                FROM check_ins
                ORDER BY trip_id, position
            """)
            groups = {trip_id: [] for trip_id in trips}
            for row in rows:
                check_in = dict(row)
                trip_id = check_in.pop("trip_id")
                groups[trip_id].append(check_in)
        return jsonify(records=list(groups.values()))

    @app.route("/predict_poi", methods=["POST"])
    def predict_poi():
        payload, error = demo_input()
        if error:
            return error
        sequence = payload.get("sequence_num")
        if type(sequence) is not int:
            return jsonify(error="sequence_num must be an integer"), 400
        if sequence not in trips:
            return jsonify(error="trip not found"), 404
        return jsonify(predicted_poi=trips[sequence]["recommendation"], mode="demo")

    return app


if __name__ == "__main__":
    create_app().run(host="127.0.0.1", port=5000)
