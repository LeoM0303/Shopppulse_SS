"""Read-only access to the report snapshots the worker stores in blob storage.

The API identity holds Storage Blob Data Reader, the worker holds Contributor, so
a bug in the API cannot damage the archive.
"""

import logging
import os

from fastapi import APIRouter, HTTPException, Query

logger = logging.getLogger(__name__)
router = APIRouter()

ACCOUNT_URL = os.environ.get("REPORTS_STORAGE_ACCOUNT_URL", "")
CONTAINER = os.environ.get("REPORTS_CONTAINER", "reports")

_container_client = None


async def get_container_client():
    global _container_client
    if _container_client is None:
        from azure.identity.aio import DefaultAzureCredential
        from azure.storage.blob.aio import BlobServiceClient

        service = BlobServiceClient(ACCOUNT_URL, credential=DefaultAzureCredential())
        _container_client = service.get_container_client(CONTAINER)
    return _container_client


@router.get("/reports")
async def list_reports(limit: int = Query(20, ge=1, le=100)):
    if not ACCOUNT_URL:
        raise HTTPException(status_code=503, detail="Report storage is not configured")

    container = await get_container_client()
    snapshots = []
    async for blob in container.list_blobs():
        snapshots.append(
            {
                "name": blob.name,
                "size_bytes": blob.size,
                "created_at": blob.last_modified.isoformat() if blob.last_modified else None,
                "tier": blob.blob_tier,
            }
        )

    snapshots.sort(key=lambda s: s["name"], reverse=True)
    return {"container": CONTAINER, "count": len(snapshots), "snapshots": snapshots[:limit]}
