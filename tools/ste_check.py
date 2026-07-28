"""STE-informed markdown checker for phoenixml.dev language-reference docs."""
import re
import sys
from dataclasses import dataclass, field

import yaml


@dataclass
class Config:
    max_sentence_words: int = 25
    banned: dict = field(default_factory=dict)
    terminology: list = field(default_factory=list)
    allow_analogy_terms: list = field(default_factory=list)
    callout_prefixes: list = field(default_factory=list)
    placeholder_markers: list = field(default_factory=list)


@dataclass
class Line:
    lineno: int
    text: str
    is_callout: bool


def load_config(path: str) -> Config:
    with open(path, encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    return Config(
        max_sentence_words=int(data.get("max_sentence_words", 25)),
        banned=dict(data.get("banned", {})),
        terminology=list(data.get("terminology", [])),
        allow_analogy_terms=list(data.get("allow_analogy_terms", [])),
        callout_prefixes=list(data.get("callout_prefixes", [])),
        placeholder_markers=list(data.get("placeholder_markers", [])),
    )


_INLINE_CODE = re.compile(r"`[^`]*`")
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")


def strip_markdown(source: str) -> list:
    lines = source.splitlines()
    out = []
    in_front = False
    in_fence = False
    for i, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        # front-matter: leading --- ... ---
        if i == 1 and stripped == "---":
            in_front = True
            out.append(Line(i, "", False))
            continue
        if in_front:
            out.append(Line(i, "", False))
            if stripped == "---":
                in_front = False
            continue
        # fenced code
        if stripped.startswith("```"):
            in_fence = not in_fence
            out.append(Line(i, "", False))
            continue
        if in_fence:
            out.append(Line(i, "", False))
            continue
        # table rows
        if stripped.startswith("|") or re.match(r"^[-:| ]+$", stripped):
            out.append(Line(i, "", False))
            continue
        # blockquotes are prose; callout status determined later by mark_callouts
        text = raw
        if stripped.startswith(">"):
            text = stripped.lstrip(">").strip()
        # replace links with their text, drop inline code
        text = _LINK.sub(r"\1", text)
        text = _INLINE_CODE.sub("", text)
        out.append(Line(i, text, False))
    return out


def mark_callouts(lines: list, config: Config) -> list:
    for ln in lines:
        for pref in config.callout_prefixes:
            if ln.text.strip().startswith(pref):
                ln.is_callout = True
                break
    return lines


@dataclass
class Finding:
    line: int
    severity: str
    code: str
    message: str


_SENT_SPLIT = re.compile(r"(?<=[.!?])\s+")


def _sentences(lines: list):
    """Yield (start_lineno, sentence_text) across contiguous prose lines."""
    buf, start = [], None
    for ln in lines:
        if ln.text.strip():
            if start is None:
                start = ln.lineno
            buf.append(ln.text.strip())
        else:
            if buf:
                yield from _emit(start, " ".join(buf))
            buf, start = [], None
    if buf:
        yield from _emit(start, " ".join(buf))


def _emit(start, blob):
    for sent in _SENT_SPLIT.split(blob):
        sent = sent.strip()
        if sent:
            yield start, sent


def _word_re(term: str):
    return re.compile(r"\b" + re.escape(term) + r"\b", re.IGNORECASE)


def check_banned(lines: list, config: Config) -> list:
    findings = []
    for ln in lines:
        if ln.is_callout or not ln.text.strip():
            continue
        for term, repl in config.banned.items():
            if _word_re(term).search(ln.text):
                findings.append(Finding(
                    ln.lineno, "error", "banned-word",
                    f"avoid \"{term}\" -> {repl}",
                ))
    return findings


def check_terminology(lines: list, config: Config) -> list:
    findings = []
    for ln in lines:
        if ln.is_callout or not ln.text.strip():
            continue
        for entry in config.terminology:
            canonical = entry.get("canonical", "")
            for variant in entry.get("variants", []):
                if _word_re(variant).search(ln.text):
                    findings.append(Finding(
                        ln.lineno, "error", "terminology",
                        f"use \"{canonical}\" not \"{variant}\"",
                    ))
    return findings


def check_sentence_length(lines: list, config: Config) -> list:
    findings = []
    for start, sent in _sentences(lines):
        words = [w for w in re.split(r"\s+", sent) if w]
        if len(words) > config.max_sentence_words:
            findings.append(Finding(
                start, "error", "sentence-length",
                f"sentence has {len(words)} words (max {config.max_sentence_words}): "
                f"\"{sent[:60]}...\"",
            ))
    return findings
