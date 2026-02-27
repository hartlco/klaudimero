from __future__ import annotations

import json
import logging

from .config import load_apns_config
from .models import Execution, Job
from .storage import load_all_devices

logger = logging.getLogger("klaudimero.notifications")


async def notify_job_event(job: Job, execution: Execution, event: str) -> None:
    """Send push notification to all registered devices."""
    apns_config = load_apns_config()
    if not apns_config:
        logger.debug("No APNs config found, skipping notification")
        return

    devices = load_all_devices()
    if not devices:
        logger.debug("No registered devices, skipping notification")
        return

    try:
        from aioapns import APNs, NotificationRequest
    except ImportError:
        logger.warning("aioapns not installed, skipping push notifications")
        return

    key_file = apns_config.get("key_file")
    key_id = apns_config.get("key_id")
    team_id = apns_config.get("team_id")
    bundle_id = apns_config.get("bundle_id")

    if not all([key_file, key_id, team_id, bundle_id]):
        logger.warning("Incomplete APNs config, skipping notification")
        return

    titles = {
        "started": f"Job Started: {job.name}",
        "completed": f"Job Completed: {job.name}",
        "failed": f"Job Failed: {job.name}",
    }
    bodies = {
        "started": f"Running: {job.prompt[:100]}",
        "completed": f"Finished in {execution.duration_seconds or 0:.1f}s",
        "failed": f"Exit code: {execution.exit_code}",
    }

    title = titles.get(event, f"Job {event}: {job.name}")
    body = bodies.get(event, "")

    try:
        with open(key_file) as f:
            key_content = f.read()

        apns = APNs(
            key=key_content,
            key_id=key_id,
            team_id=team_id,
            topic=bundle_id,
            use_sandbox=apns_config.get("sandbox", False),
        )

        for device in devices:
            request = NotificationRequest(
                device_token=device.token,
                message={
                    "aps": {
                        "alert": {"title": title, "body": body},
                        "sound": "default",
                    },
                    "job_id": job.id,
                    "execution_id": execution.id,
                    "event": event,
                },
            )
            response = await apns.send_notification(request)
            if not response.is_successful:
                logger.warning(
                    f"Failed to send push to {device.token[:8]}...: {response.description}"
                )
    except Exception as e:
        logger.error(f"APNs error: {e}")


async def notify_heartbeat_event(execution: Execution, event: str) -> None:
    """Send push notification for heartbeat execution."""
    apns_config = load_apns_config()
    if not apns_config:
        return

    devices = load_all_devices()
    if not devices:
        return

    try:
        from aioapns import APNs, NotificationRequest
    except ImportError:
        logger.warning("aioapns not installed, skipping push notifications")
        return

    key_file = apns_config.get("key_file")
    key_id = apns_config.get("key_id")
    team_id = apns_config.get("team_id")
    bundle_id = apns_config.get("bundle_id")

    if not all([key_file, key_id, team_id, bundle_id]):
        return

    if event == "failed":
        title = "Heartbeat Failed"
        body = f"Exit code: {execution.exit_code}"
    else:
        title = "Heartbeat"
        body = execution.output.strip()[:200]

    try:
        with open(key_file) as f:
            key_content = f.read()

        apns = APNs(
            key=key_content,
            key_id=key_id,
            team_id=team_id,
            topic=bundle_id,
            use_sandbox=apns_config.get("sandbox", False),
        )

        for device in devices:
            request = NotificationRequest(
                device_token=device.token,
                message={
                    "aps": {
                        "alert": {"title": title, "body": body},
                        "sound": "default",
                    },
                    "heartbeat": True,
                    "execution_id": execution.id,
                    "event": event,
                },
            )
            response = await apns.send_notification(request)
            if not response.is_successful:
                logger.warning(
                    f"Failed to send push to {device.token[:8]}...: {response.description}"
                )
    except Exception as e:
        logger.error(f"APNs error (heartbeat): {e}")
