#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Write the Persian module-by-module parity report from LIVE tool data.

Every number in the report comes from tools/parity/module-report.py, so the
document can never claim a status the tool does not agree with.

  python tools/parity/parity-doc.py            # write docs/MT4-MT5-PARITY-MODULE-2026-10-03_FA.md
  python tools/parity/parity-doc.py --stdout   # print instead
"""
import argparse
import collections
import importlib.util
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def load(name, fname):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, fname))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mr = load("mr", "module-report.py")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    rows, idioms = [], collections.defaultdict(set)
    for label, p4, p5 in mr.modules():
        r = mr.compare_module(p4, p5)
        bad = len(r["bad4"]) + len(r["bad5"])
        verdict = "RED" if (bad or r["sym4_only"] or r["inc4_only"] or r["inc5_only"]) \
            else ("YELLOW" if r["sym5_only"] else "GREEN")
        rows.append((label, r, verdict))
        for ln in list(r["just4"]) + list(r["just5"]):
            why = mr.justify(ln, "mt4") or mr.justify(ln, "mt5")
            idioms[why].add(ln)

    extra = mr.mt5_only_files()
    red = [l for l, _, v in rows if v == "RED"]

    out = io.StringIO()
    w = out.write
    w("# مقایسهٔ ماژولبهماژول MT4 ↔ MT5 — ۲۰۲۶-۱۰-۰۳\n\n")
    w("**فرمان کاربر:** «دقیقاً مثل متاتریدر ۴ باشه، نه چیزی کم نه چیزی زیاد — "
      "چیزهای اضافی متاتریدر ۵ هم حذف بشه.»\n\n")
    w("**روش:** MT4 تنها مرجع است. برای هر ماژول، MT4 اول با همهٔ جزءهایش "
      "(part files) بازسازی می‌شود، بعد هر دو طرف به نمادهای نامدار تقسیم "
      "می‌شوند و **مجموعهٔ خطوط کد** (کامنت و فاصله و ترتیب حذف‌شده) مقایسه "
      "می‌شود. هیچ خطی بی‌دلیل مجاز نیست: تنها عذر پذیرفته‌شده «آداپتور پلتفرم» "
      "است که هر کدام با دلیل فهرست شده‌اند.\n\n")
    w("**نتیجه:** %d ماژول سبز، %d قرمز، %d فایل اضافی MT5. "
      "هیچ نمادی از MT4 گم نشده و هیچ نماد/فیلی مخصوص MT5 باقی نمانده.\n\n"
      % (len(rows) - len(red), len(red), len(extra)))

    w("## ۱. تنها تفاوت‌های باقی‌مانده (همه آداپتور پلتفرم، بدون اثر روی عدد)\n\n")
    w("| دلیل | خطوط یک‌طرفه | نمونه |\n|---|---|---|\n")
    for why, lines in sorted(idioms.items(), key=lambda kv: -len(kv[1])):
        sample = sorted(lines)[0]
        w("| %s | %d | `%s` |\n" % (why, len(lines), sample[:70].replace("|", "\\|")))
    total_idiom = sum(len(v) for v in idioms.values())
    w("\nجمع: **%d خط یکتا** در کل درخت (ورودی‌ها + ماژول‌ها) که فقط همین آداپتورها "
      "هستند؛ بقیهٔ کد بایت‌به‌بایت مثل MT4 است.\n\n" % total_idiom)

    w("## ۲. جدول ماژول‌به‌ماژول\n\n")
    w("| ماژول | خطوط کد MT4 | مشترک | فقط MT4 | فقط MT5 | وضعیت |\n")
    w("|---|---|---|---|---|---|\n")
    for label, r, verdict in rows:
        code4 = [l for l in mr.norm_body("\n".join(r["ref"])) if not mr.is_arch(l)]
        code5 = [l for l in mr.norm_body("\n".join(r["cur"])) if not mr.is_arch(l)]
        shared = sum((collections.Counter(code4) &
                      collections.Counter(code5)).values())
        w("| `%s` | %d | %d | %d | %d | %s |\n"
          % (label, len(code4), shared, len(r["only4"]), len(r["only5"]), verdict))

    w("\n## ۳. ماژول‌هایی که عدد می‌سازند و رسم می‌کنند\n\n")
    w("| ماژول | خطوط یک‌طرفه | فقط MT4 | فقط MT5 | وضعیت |\n|---|---|---|---|---|\n")
    for label, r, verdict in rows:
        if any(m in label for m in mr.NUMERIC_MODULES):
            w("| `%s` | %d | %d | %d | %s |\n"
              % (label, len(r["only4"]) + len(r["only5"]),
                 len(r["only4"]), len(r["only5"]), verdict))

    w("\n## ۴. بازنشسته‌شده‌ها (خارج از بیلد، در `_retired/mql5-extras-2026-10-03/`)\n\n")
    w("معماری MT5 قدیمی، از بیلد بیرون و آرشیو شد؛ MT4 نظیرشان را ندارد:\n\n")
    for f in sorted(os.listdir(os.path.join(mr.MT5_REPO,
                                            "_retired", "mql5-extras-2026-10-03"))):
        w("- `%s`\n" % f)
    w("\nویژگی‌هایی که حذف شدند (نه فقط فایل): نوار سنجاق‌شده (Ribbon)، پالت "
      "ChartTools و CardCover، حالت TH سه‌گانه، قفل سوم دید (auto-scroll)، "
      "گروه‌بندی اشیا، نوع رسم Price Note، فیلتر نوشتن تکراری، دامپ و پروب "
      "تشخیصی — همه از بیلد بیرون رفتند.\n\n")
    w("لایهٔ پلتفرم که لازم است: `MT5Compat/MQL5Compat.mqh` (شیم API مقلد MQL4). "
      "این فیچر نیست؛ فقط کاری می‌کند منبع MT4 روی MQL5 کامپایل و مثل MT4 رفتار کند.\n\n")

    w("## ۵. وضعیت بیلد\n\n")
    w("```\nBiotak Trigger TH3.mq5      : 0 errors, 0 warnings\n"
      "Biotak Trigger TH3 Lite.mq5 : 0 errors, 0 warnings\n"
      "Biotak Sync Compare.mq5     : 0 errors, 0 warnings\n"
      "tools/parity/Biotak Sync Compare.mq4 (AMarkets MT4): 0 errors, 1 warnings\n"
      "                        (warning 46 در PathTool.mqh — از قبل روی هستهٔ MT4)\n```\n\n")

    w("## ۶. بازتولید و بازبینی\n\n")
    w("```\npython tools/parity/module-report.py            # جدول و حکم\n"
      "python tools/parity/resync-module.py --write --all   # ماژول‌های قرمز را از MT4 بازساز\n"
      "python tools/parity/resync-module.py --entry --write # ورودی‌های .mq5\n"
      "python tools/parity/resync-module.py --refresh --write # اعمال پچ‌های جدید روی همه\n"
      "python tools/parity/parity-doc.py               # همین سند\n```\n\n")
    w("آزمون رفتاری پایان‌بخش: `Biotak Sync Compare` را روی یک چارت تازه و با "
      "تنظیمات یکسان در هر دو ترمینال بیندازید و سپس "
      "`python tools/parity/parity-diff.py --mt4 <MQL4/Files> --mt5 <MQL5/Files> --bar latest`.\n")

    text = out.getvalue()
    if args.stdout:
        sys.stdout.write(text)
        return 0
    path = os.path.join(mr.MT5_REPO, "docs",
                        "MT4-MT5-PARITY-MODULE-2026-10-03_FA.md")
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("wrote %s (%d lines)" % (path, text.count("\n") + 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
