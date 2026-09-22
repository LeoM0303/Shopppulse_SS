from datetime import datetime, timezone

from app.routers import reports


class FakeBlob:
    def __init__(self, name, size, tier):
        self.name = name
        self.size = size
        self.blob_tier = tier
        self.last_modified = datetime(2026, 9, 21, 16, 5, tzinfo=timezone.utc)


class FakeContainer:
    def __init__(self, blobs):
        self._blobs = blobs

    async def list_blobs(self):
        for blob in self._blobs:
            yield blob


def test_reports_are_unavailable_until_storage_is_configured(client):
    response = client.get("/api/reports")

    assert response.status_code == 503
    assert "not configured" in response.json()["detail"]


def test_newest_snapshots_come_first(client, monkeypatch):
    blobs = [
        FakeBlob("2026-09-20/summary-090000.json", 120, "Hot"),
        FakeBlob("2026-09-21/summary-160509.json", 140, "Cool"),
    ]
    monkeypatch.setattr(reports, "ACCOUNT_URL", "https://acct.blob.core.windows.net")
    monkeypatch.setattr(reports, "get_container_client", _returning(FakeContainer(blobs)))

    body = client.get("/api/reports").json()

    assert body["count"] == 2
    assert [s["name"] for s in body["snapshots"]] == [
        "2026-09-21/summary-160509.json",
        "2026-09-20/summary-090000.json",
    ]
    assert body["snapshots"][0]["tier"] == "Cool"


def test_limit_caps_the_number_of_snapshots(client, monkeypatch):
    blobs = [FakeBlob(f"2026-09-2{i}/summary-000000.json", 10, "Hot") for i in range(1, 4)]
    monkeypatch.setattr(reports, "ACCOUNT_URL", "https://acct.blob.core.windows.net")
    monkeypatch.setattr(reports, "get_container_client", _returning(FakeContainer(blobs)))

    body = client.get("/api/reports?limit=1").json()

    assert body["count"] == 3
    assert len(body["snapshots"]) == 1


def _returning(value):
    async def factory():
        return value

    return factory
