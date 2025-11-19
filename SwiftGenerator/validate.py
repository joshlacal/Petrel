#!/usr/bin/env python3
"""
Validation script to check generated Swift code structure.
This can run without Swift being installed.
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Set


class SwiftCodeValidator:
    def __init__(self, output_path: str):
        self.output_path = Path(output_path)
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.files_checked = 0

    def validate_all(self) -> bool:
        """Validate all generated Swift files"""
        print(f"Validating generated code in: {self.output_path}")

        if not self.output_path.exists():
            self.errors.append(f"Output path does not exist: {self.output_path}")
            return False

        swift_files = list(self.output_path.glob("*.swift"))

        if not swift_files:
            self.errors.append("No Swift files found in output directory")
            return False

        print(f"Found {len(swift_files)} Swift files")

        for file_path in swift_files:
            self.validate_file(file_path)

        self.print_results()
        return len(self.errors) == 0

    def validate_file(self, file_path: Path):
        """Validate a single Swift file"""
        self.files_checked += 1

        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception as e:
            self.errors.append(f"{file_path.name}: Failed to read file: {e}")
            return

        # Check for required imports
        if "import Foundation" not in content:
            self.errors.append(f"{file_path.name}: Missing 'import Foundation'")

        # Check for lexicon comment
        if not re.search(r"// lexicon: \d+, id:", content):
            self.warnings.append(f"{file_path.name}: Missing lexicon header comment")

        # Check for basic Swift syntax
        self.check_syntax(file_path.name, content)

        # Check for protocol conformances
        self.check_protocols(file_path.name, content)

        # Check for required methods
        self.check_methods(file_path.name, content)

    def check_syntax(self, filename: str, content: str):
        """Basic Swift syntax checks"""
        # Check for unbalanced braces
        open_braces = content.count("{")
        close_braces = content.count("}")

        if open_braces != close_braces:
            self.errors.append(
                f"{filename}: Unbalanced braces (open: {open_braces}, close: {close_braces})"
            )

        # Check for common Swift patterns
        if "public struct" in content or "public enum" in content:
            # Should have CodingKeys if it has Codable
            if "Codable" in content and "enum CodingKeys" not in content:
                self.warnings.append(f"{filename}: Has Codable but no CodingKeys enum")

        # Check for proper type identifier
        if re.search(r"public static let typeIdentifier", content):
            if not re.search(r'typeIdentifier = "[a-z0-9.#-]+"', content):
                self.errors.append(f"{filename}: Invalid typeIdentifier format")

    def check_protocols(self, filename: str, content: str):
        """Check for required protocol conformances"""
        # If it's a struct, should conform to ATProtocolCodable and ATProtocolValue
        struct_matches = re.findall(r"public struct \w+: ([^{]+){", content)

        for conformances in struct_matches:
            if "ATProtocolCodable" not in conformances:
                self.warnings.append(
                    f"{filename}: Struct missing ATProtocolCodable conformance"
                )
            if "ATProtocolValue" not in conformances:
                self.warnings.append(
                    f"{filename}: Struct missing ATProtocolValue conformance"
                )

        # Enums should have proper conformances
        enum_matches = re.findall(r"public enum \w+: ([^{]+){", content)

        for conformances in enum_matches:
            if "Codable" not in conformances and "ATProtocolCodable" not in conformances:
                self.warnings.append(
                    f"{filename}: Enum missing Codable/ATProtocolCodable conformance"
                )

    def check_methods(self, filename: str, content: str):
        """Check for required methods"""
        # If struct has ATProtocolCodable, should have required methods
        if "ATProtocolCodable" in content:
            required_methods = [
                "init(from decoder: Decoder)",
                "encode(to encoder: Encoder)",
                "toCBORValue()",
                "hash(into hasher:",
                "isEqual(to other:",
            ]

            for method in required_methods:
                if method not in content:
                    self.warnings.append(f"{filename}: Missing method: {method}")

    def print_results(self):
        """Print validation results"""
        print("\n" + "=" * 60)
        print(f"Validation Results for {self.files_checked} files")
        print("=" * 60)

        if self.errors:
            print(f"\n❌ ERRORS ({len(self.errors)}):")
            for error in self.errors:
                print(f"  - {error}")

        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"  - {warning}")

        if not self.errors and not self.warnings:
            print("\n✅ All validations passed!")

        print("\nSummary:")
        print(f"  Files checked: {self.files_checked}")
        print(f"  Errors: {len(self.errors)}")
        print(f"  Warnings: {len(self.warnings)}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python validate.py <output-path>")
        print("Example: python validate.py ../Sources/Petrel/Generated")
        sys.exit(1)

    output_path = sys.argv[1]
    validator = SwiftCodeValidator(output_path)

    success = validator.validate_all()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
