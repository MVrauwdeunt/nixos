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

            distance_m = activity.get("distance") or 0

            result.append(
                {
                    "activity_id": activity_id,
                    "name": activity.get("activityName"),
                    "date": activity.get("startTimeLocal"),
                    "distance_m": round(distance_m, 1),
                    "distance_km": round(distance_m / 1000, 3),
                    "gear": (
                        {
                            "uuid": bike.get("uuid"),
                            "pk": bike.get("gearPk"),
                            "name": get_gear_name(bike),
                        }
                        if bike
                        else None
                    ),
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
