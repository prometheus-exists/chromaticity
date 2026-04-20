import time
from typing import Optional

import numpy as np


VERTEX_SHADER = """
#version 330
in vec2 in_vert;
void main() { gl_Position = vec4(in_vert, 0.0, 1.0); }
"""


def _wrap_shadertoy(frag_source: str, width: int, height: int) -> str:
    """Wrap Shadertoy mainImage into a standard fragment shader."""
    return f"""
#version 330
uniform float iTime;
uniform vec2 iResolution;
out vec4 fragColor;
{frag_source}
void main() {{
    mainImage(fragColor, gl_FragCoord.xy);
}}
"""


def render_frames(
    glsl_source: str,
    itime_values: list[float],
    resolution: tuple[int, int] = (512, 512),
    warmup_frames: int = 0,
    timeout_seconds: float = 60.0,
) -> tuple[list[Optional[np.ndarray]], Optional[str]]:
    """
    Render one frame per itime value. Returns (frames, error).
    frames[i] is None if rendering failed for that sample.
    error is None on success, string message on compilation failure.
    """
    try:
        import moderngl
    except ImportError:
        return [], "moderngl not installed"

    try:
        ctx = moderngl.create_standalone_context()
    except Exception as e:
        return [], f"Failed to create OpenGL context: {e}"

    width, height = resolution
    frag = _wrap_shadertoy(glsl_source, width, height)

    try:
        prog = ctx.program(
            vertex_shader=VERTEX_SHADER,
            fragment_shader=frag,
        )
    except Exception as e:
        ctx.release()
        return [], str(e)

    vbo = ctx.buffer(
        np.array(
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
    )
    vao = ctx.simple_vertex_array(prog, vbo, "in_vert")
    fbo = ctx.simple_framebuffer((width, height))
    fbo.use()

    if "iResolution" in prog:
        prog["iResolution"].value = (float(width), float(height))

    frames = []
    deadline = time.time() + timeout_seconds

    for itime in itime_values:
        if time.time() > deadline:
            frames.append(None)
            continue
        if "iTime" in prog:
            prog["iTime"].value = float(itime)
        ctx.clear()
        vao.render()
        raw = fbo.read(components=4, dtype="f4")
        frame = np.frombuffer(raw, dtype=np.float32).reshape(height, width, 4)
        frames.append(frame)

    ctx.release()
    return frames, None
