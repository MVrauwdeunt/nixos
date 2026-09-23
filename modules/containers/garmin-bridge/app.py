from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query
from garminconnect import Garmin

TOKEN_DIR = "/data/tokens"

garmin = None


def get_gear_name(gear):
    if not gear:
        return None

    return (
        gear.get("customMakeModel")
        or gear.get("displayName")
        or gear.get("gearModelName")
    )


def to_float(value):
    if value is None:
        return None

    try:
        return float(value)
    except (TypeError, ValueError):
        return None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global garmin

    garmin = Garmin()
    garmin.login(TOKEN_DIR)

    print("Garmin login via stored tokens successful")

    yield


app = FastAPI(
    title="Garmin Bridge",
    lifespan=lifespan,
)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "garmin_authenticated": garmin is not None,
    }


@app.get("/activities")
def activities(
    limit: int = Query(default=20, ge=1, le=100)
):
    try:
        garmin_activities = garmin.get_activities(
            start=0,
            limit=limit,
            activitytype="cycling",
        )

        result = []

        # Voorkom meerdere identieke Garmin calls voor dezelfde fiets.
        stats_cache = {}

        for activity in garmin_activities:
            activity_id = activity.get("activityId")

            if not activity_id:
                continue

            try:
                gear_list = garmin.get_activity_gear(activity_id)
            except Exception as exc:
                print(
                    f"Gear lookup failed for activity {activity_id}: {exc}"
                )
                gear_list = []

            bike = next(
                (
                    gear
                    for gear in gear_list
                    if gear.get("gearTypeName") == "Bike"
                ),
                None,
            )

            gear_data = None

            if bike:
                gear_uuid = bike.get("uuid")
                stats = {}

                if gear_uuid:
                    if gear_uuid not in stats_cache:
                        try:
                            stats_cache[gear_uuid] = (
                                garmin.get_gear_stats(gear_uuid) or {}
                            )
                        except Exception as exc:
                            print(
                                f"Gear stats lookup failed for {gear_uuid}: {exc}"
                            )
                            stats_cache[gear_uuid] = {}

                    stats = stats_cache[gear_uuid]

                total_distance_m = to_float(stats.get("totalDistance"))

                gear_data = {
                    "uuid": gear_uuid,
                    "pk": bike.get("gearPk"),
                    "name": get_gear_name(bike),
                    "total_distance_m": (
                        round(total_distance_m, 1)
                        if total_distance_m is not None
                        else None
                    ),
                    "total_distance_km": (
                        round(total_distance_m / 1000, 3)
                        if total_distance_m is not None
                        else None
                    ),
                    "total_activities": stats.get("totalActivities"),
                }

            distance_m = activity.get("distance") or 0

            result.append(
                {
                    "activity_id": activity_id,
                    "name": activity.get("activityName"),
                    "date": activity.get("startTimeLocal"),
                    "distance_m": round(distance_m, 1),
                    "distance_km": round(distance_m / 1000, 3),
                    "gear": gear_data,
                }
            )

        return result

    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Garmin error: {exc}",
        )


@app.get("/activities/{activity_id}/gear")
def activity_gear(activity_id: int):
    try:
        return garmin.get_activity_gear(activity_id)

    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Garmin error: {exc}",
        )


@app.get("/gear/{gear_uuid}/stats")
def gear_stats(gear_uuid: str):
    try:
        stats = garmin.get_gear_stats(gear_uuid)

        total_distance_m = to_float(stats.get("totalDistance"))

        return {
            "uuid": gear_uuid,
            "total_distance_m": (
                round(total_distance_m, 1)
                if total_distance_m is not None
                else None
            ),
            "total_distance_km": (
                round(total_distance_m / 1000, 3)
                if total_distance_m is not None
                else None
            ),
            "total_activities": stats.get("totalActivities"),
            "raw": stats,
        }

    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Garmin error: {exc}",
        )
