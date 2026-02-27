from __future__ import annotations

from fastapi import APIRouter, HTTPException

from ..models import Device, DeviceRegister
from ..storage import save_device, delete_device, load_all_devices

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("", status_code=201)
async def register_device(data: DeviceRegister) -> Device:
    device = Device(token=data.token, name=data.name)
    save_device(device)
    return device


@router.delete("/{token}", status_code=204)
async def unregister_device(token: str) -> None:
    if not delete_device(token):
        raise HTTPException(404, "Device not found")


@router.get("")
async def list_devices() -> list[Device]:
    return load_all_devices()
