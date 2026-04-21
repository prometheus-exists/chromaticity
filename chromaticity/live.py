from __future__ import annotations

import time
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

import numpy as np

from .audio import (
    AudioFeatureBuffer,
    AudioFeatures,
    NullAudioSource,
    SoundDeviceAudioSource,
)
from .glsl_parser import UniformInfo, parse_uniforms
from .mapper import UniformMapper
from .renderer import VERTEX_SHADER, _wrap_shadertoy


@dataclass(slots=True)
class LiveRunStats:
    frames_rendered: int
    audio_mode: str
    duration_seconds: float
    warning: str | None = None


class RenderBackend(Protocol):
    def should_close(self) -> bool: ...
    def render_frame(
        self,
        uniforms: dict[str, float],
        frame_index: int,
        delta_seconds: float,
    ) -> None: ...
    def close(self) -> None: ...


class HeadlessBackend:
    """Offscreen backend used in tests and non-windowed smoke runs."""

    def __init__(self, shader_source: str, uniform_infos: list[UniformInfo], width: int, height: int):
        try:
            import moderngl
        except ImportError as exc:
            raise RuntimeError("moderngl is not installed") from exc

        self._moderngl = moderngl
        self._uniform_infos = uniform_infos
        self._ctx = moderngl.create_standalone_context()
        self._program = self._ctx.program(
            vertex_shader=VERTEX_SHADER,
            fragment_shader=_wrap_shadertoy(shader_source, width, height),
        )
        self._width = width
        self._height = height
        vertices = np.array(
            [
                -1.0,
                -1.0,
                1.0,
                -1.0,
                -1.0,
                1.0,
                1.0,
                -1.0,
                -1.0,
                1.0,
                1.0,
                1.0,
            ],
            dtype="f4",
        )
        self._vbo = self._ctx.buffer(vertices)
        self._vao = self._ctx.vertex_array(self._program, [(self._vbo, "2f", "in_vert")])
        self._fbo = self._ctx.framebuffer(
            color_attachments=[self._ctx.renderbuffer((width, height), 4, dtype="f4")]
        )
        self._textures = self._bind_stub_textures()
        self._fbo = self._ctx.framebuffer(
            color_attachments=[self._ctx.renderbuffer((width, height), 4, dtype="f4")]
        )
        self._set_builtin_uniforms(frame_index=0, delta_seconds=0.0)

    def _bind_stub_textures(self) -> list[object]:
        stub = np.array([[[128, 128, 128, 255]]], dtype=np.uint8)
        textures = []
        for channel in range(4):
            uniform_name = f"iChannel{channel}"
            if uniform_name not in self._program:
                continue
            texture = self._ctx.texture((1, 1), 4, stub.tobytes())
            texture.use(location=channel)
            self._program[uniform_name].value = channel
            textures.append(texture)
        return textures

    def should_close(self) -> bool:
        return False

    def render_frame(
        self,
        uniforms: dict[str, float],
        frame_index: int,
        delta_seconds: float,
    ) -> None:
        self._fbo.use()
        self._set_builtin_uniforms(frame_index=frame_index, delta_seconds=delta_seconds)
        self._apply_uniforms(uniforms)
        self._ctx.clear()
        self._vao.render()

    def _set_builtin_uniforms(self, frame_index: int, delta_seconds: float) -> None:
        if "iResolution" in self._program:
            self._program["iResolution"].value = (
                float(self._width),
                float(self._height),
                1.0,
            )
        if "iMouse" in self._program:
            self._program["iMouse"].value = (0.0, 0.0, 0.0, 0.0)
        if "iFrame" in self._program:
            self._program["iFrame"].value = frame_index
        if "iTimeDelta" in self._program:
            self._program["iTimeDelta"].value = float(delta_seconds)

    def _apply_uniforms(self, uniforms: dict[str, float]) -> None:
        for info in self._uniform_infos:
            if info.name not in uniforms or info.name not in self._program:
                continue
            value = float(uniforms[info.name])
            if info.glsl_type == "float":
                self._program[info.name].value = value
            elif info.glsl_type == "int":
                self._program[info.name].value = int(round(value))
            elif info.glsl_type == "vec2":
                self._program[info.name].value = (value, value)
            elif info.glsl_type == "vec3":
                self._program[info.name].value = (value, value, value)
            elif info.glsl_type == "vec4":
                self._program[info.name].value = (value, value, value, value)
        if "iTime" in uniforms and "iTime" in self._program:
            self._program["iTime"].value = float(uniforms["iTime"])

    def close(self) -> None:
        for texture in self._textures:
            texture.release()
        if hasattr(self, "_fbo"):
            self._fbo.release()
        self._vao.release()
        self._vbo.release()
        self._program.release()
        self._ctx.release()


class PygletBackend(HeadlessBackend):
    """Visible live window backend."""

    def __init__(
        self,
        shader_source: str,
        uniform_infos: list[UniformInfo],
        width: int,
        height: int,
        fullscreen: bool,
    ) -> None:
        try:
            import pyglet
        except ImportError as exc:
            raise RuntimeError("pyglet is not installed") from exc
        try:
            import moderngl
        except ImportError as exc:
            raise RuntimeError("moderngl is not installed") from exc

        self._pyglet = pyglet
        display = pyglet.display.get_display()
        screen = display.get_default_screen()
        self._window = pyglet.window.Window(
            width=width,
            height=height,
            fullscreen=fullscreen,
            screen=screen,
            caption="Chromaticity Live",
            resizable=not fullscreen,
            visible=True,
        )
        self._window.switch_to()
        self._moderngl = moderngl
        self._uniform_infos = uniform_infos
        self._ctx = moderngl.create_context()
        self._program = self._ctx.program(
            vertex_shader=VERTEX_SHADER,
            fragment_shader=_wrap_shadertoy(shader_source, width, height),
        )
        self._width = width
        self._height = height
        vertices = np.array(
            [
                -1.0,
                -1.0,
                1.0,
                -1.0,
                -1.0,
                1.0,
                1.0,
                -1.0,
                -1.0,
                1.0,
                1.0,
                1.0,
            ],
            dtype="f4",
        )
        self._vbo = self._ctx.buffer(vertices)
        self._vao = self._ctx.vertex_array(self._program, [(self._vbo, "2f", "in_vert")])
        self._textures = self._bind_stub_textures()
        self._set_builtin_uniforms(frame_index=0, delta_seconds=0.0)

    def should_close(self) -> bool:
        self._window.dispatch_events()
        return bool(getattr(self._window, "has_exit", False))

    def render_frame(
        self,
        uniforms: dict[str, float],
        frame_index: int,
        delta_seconds: float,
    ) -> None:
        self._window.switch_to()
        self._set_builtin_uniforms(frame_index=frame_index, delta_seconds=delta_seconds)
        self._apply_uniforms(uniforms)
        self._ctx.clear()
        self._vao.render()
        self._window.flip()

    def close(self) -> None:
        for texture in self._textures:
            texture.release()
        self._vao.release()
        self._vbo.release()
        self._program.release()
        self._ctx.release()
        self._window.close()


def _create_backend(
    shader_source: str,
    uniform_infos: list[UniformInfo],
    width: int,
    height: int,
    fullscreen: bool,
    headless: bool,
) -> RenderBackend:
    if headless:
        return HeadlessBackend(shader_source, uniform_infos, width, height)
    return PygletBackend(shader_source, uniform_infos, width, height, fullscreen)


def _create_audio_source(audio_device: int | None) -> tuple[object, str | None]:
    try:
        source = SoundDeviceAudioSource(device=audio_device)
        return source, None
    except Exception as exc:
        return NullAudioSource(), str(exc)


def run_live(
    shader_path: str,
    mapping_path: str | None = None,
    audio_device: int | None = None,
    width: int = 1280,
    height: int = 720,
    fps: int = 60,
    fullscreen: bool = False,
    *,
    duration_seconds: float | None = None,
    headless: bool = False,
) -> LiveRunStats:
    """Run the live audio-reactive renderer."""
    shader_source = Path(shader_path).read_text()
    uniform_infos = parse_uniforms(shader_source)
    mapper = UniformMapper(mapping_path=mapping_path, uniform_infos=uniform_infos)
    feature_buffer = AudioFeatureBuffer(initial=AudioFeatures.silence())

    backend = _create_backend(
        shader_source=shader_source,
        uniform_infos=uniform_infos,
        width=width,
        height=height,
        fullscreen=fullscreen,
        headless=headless,
    )
    audio_source, warning = _create_audio_source(audio_device)
    audio_mode = "live"
    try:
        try:
            audio_source.start(feature_buffer)
        except Exception as exc:
            warning = str(exc)
            audio_mode = "fallback"
            audio_source = NullAudioSource()
            audio_source.start(feature_buffer)
            warnings.warn(
                f"Audio capture unavailable, falling back to iTime-only mode: {warning}",
                RuntimeWarning,
            )

        start = time.perf_counter()
        previous = start
        frame_index = 0
        target_frame = 1.0 / max(1, fps)
        while True:
            now = time.perf_counter()
            elapsed = now - start
            if duration_seconds is not None and elapsed >= duration_seconds:
                break
            if backend.should_close():
                break

            features = feature_buffer.latest()
            uniforms = mapper.map(features)
            backend.render_frame(uniforms, frame_index=frame_index, delta_seconds=now - previous)
            frame_index += 1
            previous = now

            spent = time.perf_counter() - now
            sleep_for = target_frame - spent
            if sleep_for > 0.0:
                time.sleep(sleep_for)

        return LiveRunStats(
            frames_rendered=frame_index,
            audio_mode=audio_mode,
            duration_seconds=time.perf_counter() - start,
            warning=warning,
        )
    finally:
        try:
            audio_source.close()
        finally:
            backend.close()
