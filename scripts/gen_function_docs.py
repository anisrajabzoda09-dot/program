"""Файл: docs/FUNCTIONS.md-ро аз худи код месозад — ҳар файл, ҳар функсия ва синф бо шарҳи тоҷикии он.

Манбаъҳо: docstring-ҳои Python (app/, scripts/, tests/), шарҳҳои `///` дар Dart (mobile/lib)
ва `/** */` дар Kotlin (mobile/android). Барои роутҳои FastAPI метод ва суроға ҳам навишта мешавад.

Истифода:
    venv/bin/python scripts/gen_function_docs.py          # docs/FUNCTIONS.md-ро нав мекунад
    venv/bin/python scripts/gen_function_docs.py --check  # хато, агар файл кӯҳна бошад
"""

import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "FUNCTIONS.md"

SECTIONS = [
    ("Сервер — роутҳо (API ва саҳифаҳо)", "py", ["app/routers"]),
    ("Сервер — мантиқи асосӣ", "py", ["app/core", "app/crud"]),
    ("Сервер — моделҳои база", "py", ["app/models", "app/db", "app/schemas"]),
    ("Сервер — оғоз", "py", ["app/main.py"]),
    ("Скриптҳо", "py", ["scripts"]),
    ("Санҷишҳои сервер", "py", ["tests"]),
    ("Барнома — асос (core)", "dart", ["mobile/lib/core", "mobile/lib/main.dart"]),
    ("Барнома — экранҳои волидайн", "dart", ["mobile/lib/features/parent"]),
    ("Барнома — экранҳои фарзанд", "dart", ["mobile/lib/features/child"]),
    ("Барнома — воридшавӣ ва танзимот", "dart", ["mobile/lib/features/auth", "mobile/lib/features/settings", "mobile/lib/features/onboarding"]),
    ("Барнома — чат ва занг", "dart", ["mobile/lib/features/chat", "mobile/lib/features/call"]),
    ("Барнома — UI ва тарҷума", "dart", ["mobile/lib/ui", "mobile/lib/l10n", "mobile/lib/pages"]),
    ("Android (Kotlin)", "kt", ["mobile/android/app/src/main/kotlin"]),
]

_ROUTE_DECORATORS = {"get", "post", "put", "patch", "delete", "head"}


def _first_line(text: str) -> str:
    """Сатри аввали шарҳ, бе фосилаҳои зиёдатӣ ва бе аломати «|» (барои ҷадвал)."""
    line = (text or "").strip().splitlines()[0] if (text or "").strip() else ""
    return line.replace("|", "\\|").strip()


def _files(paths, ext):
    """Ҳамаи файлҳои навъи додашударо дар роҳҳо бо тартиби алифбо бармегардонад."""
    found = []
    for rel in paths:
        p = ROOT / rel
        if p.is_file():
            found.append(p)
        elif p.is_dir():
            found.extend(sorted(x for x in p.rglob(f"*.{ext}") if "__pycache__" not in x.parts))
    return found


def _router_prefix(tree) -> str:
    """Агар файл `router = APIRouter(prefix="…")` дошта бошад, prefix-ро бармегардонад."""
    for node in tree.body:
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Call):
            for kw in node.value.keywords:
                if kw.arg == "prefix" and isinstance(kw.value, ast.Constant):
                    return str(kw.value.value)
    return ""


def _route(node, prefix: str = "") -> str:
    """Барои функсияи FastAPI «GET /path»-ро аз декоратор мегирад (бо prefix-и router)."""
    routes = []
    for dec in getattr(node, "decorator_list", []):
        if isinstance(dec, ast.Call) and isinstance(dec.func, ast.Attribute) and dec.func.attr in _ROUTE_DECORATORS:
            if dec.args and isinstance(dec.args[0], ast.Constant) and isinstance(dec.args[0].value, str):
                routes.append(f"{dec.func.attr.upper()} {prefix}{dec.args[0].value}")
    return ", ".join(r for r in routes if not r.startswith("HEAD")) or ""


def python_entries(path: Path):
    """Шарҳи файл ва рӯйхати (ном, роут, шарҳ)-и функсияҳо ва синфҳои Python."""
    tree = ast.parse(path.read_text(encoding="utf-8"))
    module_doc = _first_line(ast.get_docstring(tree) or "")
    prefix = _router_prefix(tree)
    rows = []

    def visit(nodes, owner=""):
        for node in nodes:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                rows.append((f"{owner}{node.name}()", _route(node, prefix), _first_line(ast.get_docstring(node) or "")))
            elif isinstance(node, ast.ClassDef):
                rows.append((f"class {node.name}", "", _first_line(ast.get_docstring(node) or "")))
                visit(node.body, owner=f"{node.name}.")
    visit(tree.body)
    return module_doc, rows


_DART_DECL = re.compile(
    r"^\s*(?:@override\s*)?(?:(?:static|final|const|late|abstract|factory|external|Future<[^>]*>|Stream<[^>]*>|void|[A-Z][\w<>,? ]*|bool|int|double|String|num|dynamic)\s+)*"
    r"(?P<name>(?:class|mixin|enum|extension)\s+\w+|[a-zA-Z_]\w*(?:\.\w+)?)\s*(?:[(<{=]|get\b|$)"
)


def _doc_block(lines, i, start, cont, end=None):
    """Шарҳҳои пай дар пай пеш аз сатри i-ро ҷамъ мекунад (/// ё /** … */)."""
    text = []
    j = i - 1
    while j >= 0 and lines[j].strip().startswith("@"):
        j -= 1
    while j >= 0:
        s = lines[j].strip()
        if s.startswith(start) or (cont and s.startswith(cont)) or (end and s.endswith(end)):
            text.insert(0, re.sub(r"^(///|/\*\*|\*/|\*)\s?", "", s).rstrip("*/ ").strip())
            j -= 1
        else:
            break
    return " ".join(t for t in text if t).strip()


def _source_header(lines) -> str:
    """Сатри «// Файл: …»-ро дар аввали файли Dart ё Kotlin меёбад."""
    for line in lines[:6]:
        s = line.strip()
        if s.startswith("// Файл:"):
            return s[len("// "):].replace("|", "\\|")
    return ""


def dart_entries(path: Path):
    """Функсия ва синфҳои Dart, ки пеш аз онҳо шарҳи /// ҳаст."""
    lines = path.read_text(encoding="utf-8").splitlines()
    rows = []
    for i, line in enumerate(lines):
        if not line.strip() or line.strip().startswith(("//", "*", "@", "}", ")", "import", "export", "part")):
            continue
        prev = lines[i - 1].strip() if i else ""
        if not (prev.startswith("///") or (prev.startswith("@") and i > 1 and lines[i - 2].strip().startswith("///"))):
            continue
        m = _DART_DECL.match(line)
        if not m:
            continue
        name = m.group("name")
        if name in ("return", "if", "for", "while", "switch", "final", "const", "var"):
            continue
        is_call = "(" in line[m.end("name"):m.end("name") + 2]
        label = name if name.split(" ")[0] in ("class", "mixin", "enum", "extension") else name + ("()" if is_call else "")
        rows.append((label, "", _first_line(_doc_block(lines, i, "///", None))))
    return _source_header(lines), rows


_KT_DECL = re.compile(r"^\s*(?:(?:private|internal|override|public|protected|open|abstract|data|inner|suspend|companion)\s+)*(?:fun\s+(?:[\w.<>]+\.)?(?P<fun>\w+)|(?P<kind>class|object|interface)\s+(?P<cls>\w+))")


def kotlin_entries(path: Path):
    """Функсия ва синфҳои Kotlin, ки пеш аз онҳо шарҳи KDoc ҳаст."""
    lines = path.read_text(encoding="utf-8").splitlines()
    rows = []
    for i, line in enumerate(lines):
        m = _KT_DECL.match(line)
        if not m:
            continue
        doc = _doc_block(lines, i, "/**", "*", "*/")
        if not doc:
            continue
        label = f"{m.group('fun')}()" if m.group("fun") else f"{m.group('kind')} {m.group('cls')}"
        rows.append((label, "", _first_line(doc)))
    return _source_header(lines), rows


def build() -> str:
    """Матни пурраи docs/FUNCTIONS.md-ро месозад."""
    parts = []
    total_files = total_items = 0
    toc = []
    for title, ext, paths in SECTIONS:
        files = _files(paths, ext)
        if not files:
            continue
        anchor = re.sub(r"[^\w\- ]", "", title.lower()).strip().replace(" ", "-")
        section = [f"## {title}\n"]
        count = 0
        for f in files:
            reader = {"py": python_entries, "dart": dart_entries, "kt": kotlin_entries}[ext]
            try:
                header, rows = reader(f)
            except SyntaxError:
                continue
            rel = f.relative_to(ROOT).as_posix()
            section.append(f"### `{rel}`\n")
            if header:
                section.append(f"{header.removeprefix('Файл:').strip()}\n")
            if rows:
                section.append("| Функсия / синф | Роут | Чӣ кор мекунад |\n|---|---|---|")
                for name, route, doc in rows:
                    section.append(f"| `{name}` | {f'`{route}`' if route else ''} | {doc or '—'} |")
                section.append("")
            count += len(rows)
            total_files += 1
        total_items += count
        toc.append(f"- [{title}](#{anchor}) — {len(files)} файл, {count} функсия ва синф")
        parts.append("\n".join(section))
    head = [
        "# NIGOH Family — ҳамаи функсияҳо",
        "",
        "Ин файлро скрипти `scripts/gen_function_docs.py` аз шарҳҳои тоҷикии худи код месозад —",
        "онро дастӣ таҳрир накунед. Барои фаҳмидани он ки қисмҳо бо ҳам чӣ гуна кор мекунанд,",
        "[HOW_IT_WORKS.md](HOW_IT_WORKS.md)-ро хонед.",
        "",
        f"**{total_files} файл · {total_items} функсия ва синф**",
        "",
        "## Мундариҷа",
        "",
        *toc,
        "",
    ]
    return "\n".join(head) + "\n" + "\n\n".join(parts) + "\n"


def main() -> int:
    """Файлро менависад ё бо --check месанҷад, ки он нав аст."""
    text = build()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("docs/FUNCTIONS.md кӯҳна аст: venv/bin/python scripts/gen_function_docs.py")
            return 1
        print("docs/FUNCTIONS.md нав аст")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {text.count(chr(10))} сатр")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
