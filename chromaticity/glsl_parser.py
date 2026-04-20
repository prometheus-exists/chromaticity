import re
from dataclasses import dataclass


SHADERTOY_BUILTINS = {
    "iTime",
    "iResolution",
    "iMouse",
    "iChannel0",
    "iChannel1",
    "iChannel2",
    "iChannel3",
}


@dataclass
class UniformInfo:
    name: str
    glsl_type: str
    is_builtin: bool


def parse_uniforms(glsl_source: str) -> list[UniformInfo]:
    """Extract all uniform declarations from GLSL source."""
    pattern = r"\buniform\s+(\w+)\s+(\w+)\s*;"
    results = []
    for m in re.finditer(pattern, glsl_source):
        glsl_type, name = m.group(1), m.group(2)
        results.append(
            UniformInfo(
                name=name,
                glsl_type=glsl_type,
                is_builtin=name in SHADERTOY_BUILTINS,
            )
        )
    if "mainImage" in glsl_source and not any(u.name == "iTime" for u in results):
        results.insert(0, UniformInfo(name="iTime", glsl_type="float", is_builtin=True))
    return results


def needs_ichannel0(glsl_source: str) -> bool:
    """True if shader reads from iChannel0."""
    return bool(re.search(r"\biChannel0\b", glsl_source))


def has_feedback_loop(buffer_a_source: str) -> bool:
    """True if Buffer A reads iChannel0 (self-referential feedback)."""
    return needs_ichannel0(buffer_a_source)
