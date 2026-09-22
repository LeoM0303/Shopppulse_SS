import json

import pytest

from app.main import archive_summary
from app.reports import SnapshotWriter, snapshot_blob_name

SUMMARY = {"updated_at": "2026-09-21T16:05:09+00:00", "net_revenue": 12.5}


class FakeContainer:
    def __init__(self):
        self.uploads = []

    async def upload_blob(self, name, data, overwrite, content_type):
        self.uploads.append((name, data, content_type))


class RecordingWriter(SnapshotWriter):
    """Replaces the blob client so the write path can be exercised without Azure."""

    def __init__(self, container, **kwargs):
        super().__init__(account_url="https://acct.blob.core.windows.net", **kwargs)
        self._fake = container

    async def _container_client(self):
        return self._fake


def test_blob_name_is_grouped_by_day():
    assert snapshot_blob_name(SUMMARY["updated_at"]) == "2026-09-21/summary-160509.json"


def test_writer_without_an_account_url_is_disabled():
    writer = SnapshotWriter()

    assert writer.enabled is False
    assert writer.is_due() is False


@pytest.mark.asyncio
async def test_unconfigured_writer_skips_silently():
    assert await SnapshotWriter().write_if_due(SUMMARY) is None


@pytest.mark.asyncio
async def test_first_summary_is_written_as_json():
    container = FakeContainer()
    writer = RecordingWriter(container)

    name = await writer.write_if_due(SUMMARY)

    assert name == "2026-09-21/summary-160509.json"
    uploaded_name, data, content_type = container.uploads[0]
    assert uploaded_name == name
    assert json.loads(data)["net_revenue"] == 12.5
    assert content_type == "application/json"


@pytest.mark.asyncio
async def test_writes_are_rate_limited():
    container = FakeContainer()
    now = [1000.0]
    writer = RecordingWriter(container, min_interval_seconds=900, clock=lambda: now[0])

    await writer.write_if_due(SUMMARY)
    now[0] += 60
    skipped = await writer.write_if_due(SUMMARY)

    assert skipped is None
    assert len(container.uploads) == 1


@pytest.mark.asyncio
async def test_writes_resume_once_the_interval_passes():
    container = FakeContainer()
    now = [1000.0]
    writer = RecordingWriter(container, min_interval_seconds=900, clock=lambda: now[0])

    await writer.write_if_due(SUMMARY)
    now[0] += 900
    await writer.write_if_due(SUMMARY)

    assert len(container.uploads) == 2


@pytest.mark.asyncio
async def test_a_broken_upload_does_not_propagate():
    class Broken:
        async def write_if_due(self, summary):
            raise RuntimeError("storage is unreachable")

    await archive_summary(Broken(), SUMMARY)
