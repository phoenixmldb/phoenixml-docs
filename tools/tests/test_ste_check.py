import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import ste_check as s

CONFIG = os.path.join(os.path.dirname(__file__), "..", "ste-wordlist.yaml")

def test_load_config():
    cfg = s.load_config(CONFIG)
    assert cfg.max_sentence_words == 25
    assert cfg.banned["leverage"] == "use"
    assert "For C# developers" in cfg.callout_prefixes

def test_strip_frontmatter_and_code():
    src = (
        "---\n"
        "title: X\n"
        "---\n"
        "Real prose here.\n"
        "```\n"
        "code with leverage word\n"
        "```\n"
        "Prose with `inline code` kept.\n"
        "| a | b |\n"
        "> For C# developers: think of it as LINQ.\n"
    )
    cfg = s.load_config(CONFIG)
    lines = s.mark_callouts(s.strip_markdown(src), cfg)
    by_no = {ln.lineno: ln for ln in lines}
    # front-matter lines produce empty prose
    assert by_no[2].text.strip() == ""
    # fenced code content is blanked
    assert "leverage" not in by_no[6].text
    # inline code removed but surrounding prose kept
    assert "Prose with" in by_no[8].text and "inline code" not in by_no[8].text
    # table row blanked
    assert by_no[9].text.strip() == ""
    # callout line flagged
    assert by_no[10].is_callout is True

def test_sentence_length_flags_long_sentence():
    cfg = s.load_config(CONFIG)
    long = "This sentence has far too many words in it because " + " ".join(["word"] * 30) + "."
    lines = s.mark_callouts(s.strip_markdown(long + "\n"), cfg)
    findings = s.check_sentence_length(lines, cfg)
    assert any(f.code == "sentence-length" and f.severity == "error" for f in findings)

def test_sentence_length_passes_short_sentence():
    cfg = s.load_config(CONFIG)
    lines = s.mark_callouts(s.strip_markdown("XSLT transforms XML documents.\n"), cfg)
    assert s.check_sentence_length(lines, cfg) == []

def test_banned_word_flagged_in_prose():
    cfg = s.load_config(CONFIG)
    lines = s.mark_callouts(s.strip_markdown("You can leverage the engine.\n"), cfg)
    findings = s.check_banned(lines, cfg)
    assert any(f.code == "banned-word" and "leverage" in f.message for f in findings)

def test_banned_word_allowed_in_callout():
    cfg = s.load_config(CONFIG)
    src = "> For C# developers: leverage your LINQ knowledge here.\n"
    lines = s.mark_callouts(s.strip_markdown(src), cfg)
    assert s.check_banned(lines, cfg) == []

def test_terminology_variant_flagged():
    cfg = s.load_config(CONFIG)
    lines = s.mark_callouts(s.strip_markdown("Match the opening tag first.\n"), cfg)
    findings = s.check_terminology(lines, cfg)
    assert any(f.code == "terminology" and "element" in f.message for f in findings)
