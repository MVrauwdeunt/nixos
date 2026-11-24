
"""Read-only, profile-scoped Allos SQLite adapter."""

import sqlite3
from datetime import date
from pathlib import Path
from urllib.parse import quote

TABLES = {
    "body_metrics": (
        "date", "weight_kg", "body_fat_pct", "resting_hr"
    ),
    "metric_samples": (
        "date", "metric", "value", "started_at", "ended_at"
    ),
    "hr_minutes": (
        "ts", "bpm", "bpm_min", "bpm_max"
    ),
    "glucose_trace": (
        "ts", "mgdl"
    ),
    "activities": (
        "date", "type", "duration_min", "distance_km",
        "avg_hr", "max_hr", "avg_power_w", "est_calories"
    ),
    "medical_records": (
        "date", "category", "name", "value", "unit",
        "reference_range", "flag", "panel", "loinc"
    ),
}

DATE_COLUMNS = {
    "body_metrics": "date",
    "metric_samples": "date",
    "hr_minutes": "ts",
    "glucose_trace": "ts",
    "activities": "date",
    "medical_records": "date",
}


class AllosDB:
    def __init__(self, path: str, profile_id: int):
        self.path = Path(path)
        self.profile_id = int(profile_id)

        if self.profile_id < 1 or not self.path.is_file():
            raise ValueError("Invalid database or profile")

    def connect(self):
        path = quote(str(self.path.resolve()), safe="/")
        db = sqlite3.connect(
            f"file:{path}?mode=ro",
            uri=True,
            timeout=5,
        )
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA query_only=ON")
        return db

    def catalog(self):
        return [
            {"table": name, "fields": list(fields)}
            for name, fields in TABLES.items()
        ]

    def read(self, table, start=None, end=None, limit=50):
        if table not in TABLES:
            raise ValueError("Table not allowed")

        if type(limit) is not int or not 1 <= limit <= 100:
            raise ValueError("Invalid limit")

        for value in (start, end):
            if value is not None:
                date.fromisoformat(value)

        if start and end and start > end:
            raise ValueError("Invalid date range")

        columns = TABLES[table]
        date_column = DATE_COLUMNS[table]

        query = (
            "SELECT "
            + ", ".join(f'"{c}"' for c in columns)
            + f' FROM "{table}" WHERE profile_id = ?'
        )
        params = [self.profile_id]

        if start:
            query += f' AND date("{date_column}") >= date(?)'
            params.append(start)

        if end:
            query += f' AND date("{date_column}") <= date(?)'
            params.append(end)

        query += f' ORDER BY "{date_column}" DESC LIMIT ?'
        params.append(limit)

        with self.connect() as db:
            return [
                dict(row)
                for row in db.execute(query, params)
            ]

    def metrics(self):
        with self.connect() as db:
            return [
                dict(row)
                for row in db.execute(
                    """
                    SELECT metric, COUNT(*) AS samples
                    FROM metric_samples
                    WHERE profile_id = ?
                    GROUP BY metric
                    ORDER BY metric
                    """,
                    (self.profile_id,),
                )
            ]
