"""
Rust template manager - loads and manages Jinja2 templates for Rust code generation.
"""
from __future__ import annotations

import os
from jinja2 import Environment, FileSystemLoader

from rust_enum_generator import rust_string_literal
from rust_type_converter import rust_pascal_case, rust_snake_case, sanitize_rust_ident


def escape_rust_doc(text: str) -> str:
    """Format arbitrary text as Rust `///` doc-comment lines."""
    if not text:
        return ""
    cleaned = text.replace("*/", "* /").replace("/*", "/ *")
    lines = [line.strip() for line in cleaned.splitlines() if line.strip()]
    return "\n".join(f"/// {line}" for line in lines)


def escape_rust_module_doc(text: str) -> str:
    """Format arbitrary text as Rust `//!` inner module doc-comment lines."""
    if not text:
        return ""
    cleaned = text.replace("*/", "* /").replace("/*", "/ *")
    lines = [line.strip() for line in cleaned.splitlines() if line.strip()]
    return "\n".join(f"//! {line}" for line in lines)


def escape_rust_str_literal(value: str) -> str:
    """Escape text as a Rust double-quoted string literal."""
    return rust_string_literal(value)


class RustTemplateManager:
    """Manages Jinja2 templates for deterministic Rust code generation."""

    def __init__(self) -> None:
        template_dir = os.path.join(os.path.dirname(__file__), "templates", "rust")
        self.env = Environment(
            loader=FileSystemLoader(template_dir),
            autoescape=False,
            trim_blocks=True,
            lstrip_blocks=True,
        )
        self.env.filters["snake_case"] = rust_snake_case
        self.env.filters["pascal_case"] = rust_pascal_case
        self.env.filters["rust_ident"] = sanitize_rust_ident
        self.env.filters["escape_doc"] = escape_rust_doc
        self.env.filters["escape_module_doc"] = escape_rust_module_doc
        self.env.filters["escape_str_literal"] = escape_rust_str_literal

        self.module_template = self.env.get_template("module.rs.jinja")
        self.struct_template = self.env.get_template("struct.rs.jinja")
        self.parameters_template = self.env.get_template("parameters.rs.jinja")
        self.errors_template = self.env.get_template("errors.rs.jinja")
        self.endpoint_template = self.env.get_template("endpoint.rs.jinja")
        self.subscription_template = self.env.get_template("subscription.rs.jinja")
        self.space_template = self.env.get_template("space.rs.jinja")
        self.type_alias_template = self.env.get_template("type_alias.rs.jinja")
        self.strict_ref_helper_template = self.env.get_template("strict_ref_helper.rs.jinja")
