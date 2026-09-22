"""Application Insights wiring.

Traces, metrics and logs go to the same workspace as the platform telemetry, so
an incident can be followed from an alert into the code path that caused it.
Without a connection string the app runs completely uninstrumented, which is what
local development and the test suite want.
"""

import logging
import os

logger = logging.getLogger(__name__)


def configure_telemetry(service_name: str) -> bool:
    connection_string = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
    if not connection_string:
        logger.info("Application Insights is not configured; telemetry stays local")
        return False

    os.environ.setdefault("OTEL_SERVICE_NAME", service_name)

    # Imported lazily: the distro pulls in the instrumentation packages on import.
    from azure.monitor.opentelemetry import configure_azure_monitor

    configure_azure_monitor(connection_string=connection_string)
    logger.info("Application Insights configured for %s", service_name)
    return True
