import json
import re
import sys

def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    tool_input = payload.get("tool_input") or {}
    path = tool_input.get("file_path") or (payload.get("tool_response") or {}).get("filePath") or ""
    norm = path.replace("\\", "/")
    if not re.search(r"(^|/)\.claude/agents/[^/]+\.md$", norm) and not re.search(r"(^|/)agents/[^/]+\.md$", norm.split("/.claude/")[-1] if "/.claude/" in norm else ""):
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except Exception:
        return
    problem = None
    if not text.startswith("---"):
        problem = "file does not start with '---' frontmatter block"
    else:
        m = re.search(r"^---\s*\n(.*?)\n---\s*(\n|$)", text, re.DOTALL)
        if not m:
            problem = "frontmatter block is not closed with '---'"
        else:
            try:
                import yaml
            except Exception:
                return
            try:
                data = yaml.safe_load(m.group(1))
                if not isinstance(data, dict):
                    problem = "frontmatter is not a YAML mapping"
                elif not data.get("name"):
                    problem = "frontmatter is missing 'name'"
                elif "description" in data and not isinstance(data["description"], str):
                    problem = "'description' did not parse as a string - likely an unquoted ':' turned it into a nested mapping; wrap the value in double quotes"
            except Exception as e:
                problem = "YAML parse error: " + str(e).replace("\n", " ")[:300] + " - a ':' inside an unquoted value is the usual cause; wrap the value in double quotes"
    if problem:
        print(json.dumps({
            "decision": "block",
            "reason": "Agent frontmatter INVALID in " + path + ": " + problem + ". The harness will silently drop this agent from the registry at next SessionStart. Fix the frontmatter now.",
        }))

if __name__ == "__main__":
    main()
