---
paths: ["**/*.py"]
---

# Python Rules

## Style
- Follow PEP 8
- Type hints for all function signatures in new code
- f-strings over .format() or % formatting
- `pathlib.Path` over `os.path` for file operations

## Structure
- One class/module per file when possible
- Keep functions under 30 lines — extract helpers if needed
- No wildcard imports (`from module import *`)

## Testing
- pytest for all tests
- Test file naming: `test_<module_name>.py`
- Fixtures over setUp/tearDown
