"""Report snapshots in blob storage.

The worker recomputes the dashboard summary on every batch of events, which is
far more often than anyone needs a stored copy, so writes are rate limited. When
no storage account is configured — local docker-compose, tests — every call is a
no-op and the worker keeps running as before.
"""

import json
import logging
import os
import time
from datetime import datetime

logger = logging.getLogger(__name__)


def snapshot_blob_name(updated_at: str) -> str:
    """reports are keyed by day so a lifecycle policy and a human can both navigate them."""
    moment = datetime.fromisoformat(updated_at)
    return f"{moment:%Y-%m-%d}/summary-{moment:%H%M%S}.json"


class SnapshotWriter:
    def __init__(
        self,
        account_url: str = "",
        container: str = "reports",
        min_interval_seconds: int = 900,
        clock=time.monotonic,
    ):
        self._account_url = account_url
        self._container = container
        self._min_interval = min_interval_seconds
        self._clock = clock
        self._last_write: float | None = None
        self._client = None

    @property
    def enabled(self) -> bool:
        return bool(self._account_url)

    def is_due(self) -> bool:
        if not self.enabled:
            return False
        if self._last_write is None:
            return True
        return self._clock() - self._last_write >= self._min_interval

    async def write_if_due(self, summary: dict) -> str | None:
        """Returns the blob name when a snapshot was stored, None when it was skipped."""
        if not self.is_due():
            return None

        name = snapshot_blob_name(summary["updated_at"])
        container = await self._container_client()
        await container.upload_blob(
            name=name,
            data=json.dumps(summary).encode(),
            overwrite=True,
            content_type="application/json",
        )
        self._last_write = self._clock()
        return name

    async def _container_client(self):
        if self._client is None:
            # Imported lazily so the SDK is only loaded when storage is in use.
            from azure.identity.aio import DefaultAzureCredential
            from azure.storage.blob.aio import BlobServiceClient

            service = BlobServiceClient(self._account_url, credential=DefaultAzureCredential())
            self._client = service.get_container_client(self._container)
        return self._client


def writer_from_env() -> SnapshotWriter:
    return SnapshotWriter(
        account_url=os.environ.get("REPORTS_STORAGE_ACCOUNT_URL", ""),
        container=os.environ.get("REPORTS_CONTAINER", "reports"),
        min_interval_seconds=int(os.environ.get("REPORTS_MIN_INTERVAL_SECONDS", "900")),
    )
