# -*- coding: utf-8 -*-
"""Generate Biotak Sync Compare.mq5 from the MT4 original."""
import io

SRC = r"C:\Users\Bioootak\Desktop\Trading\Biotak-Trigger-TH3-mql4\Biotak Sync Compare.mq4"
DST = r"Biotak Sync Compare.mq5"

with io.open(SRC, "r", encoding="utf-8-sig", newline="") as f:
    lines = f.read().split("\n")
lines = [ln.rstrip("\r") for ln in lines]
if lines and lines[-1] == "":
    lines.pop()

out = []
awaiting_timer_brace = False
for i, ln in enumerate(lines):
    if i == 1:
        ln = ln.replace(".mq4", ".mq5")

    # Insert CompatRefreshChartData() before the handler call in OnCalculate
    if "int res = OnCalculateHandler(rates_total, prev_calculated" in ln:
        out.append("    CompatRefreshChartData();")

    if awaiting_timer_brace and ln.strip() == "{":
        out.append(ln)
        out.append("    CompatRefreshChartData();")
        awaiting_timer_brace = False
        continue

    out.append(ln)

    if ln.strip() == "#property indicator_chart_window":
        out.append("#property indicator_plots 0")
    if ln.strip() == '#include "Biotak\\Logger.mqh"':
        out.append('#include "Biotak\\MQL5Compat.mqh"')

    if ln.strip() == "void OnTimer()":
        awaiting_timer_brace = True

text = "\r\n".join(out) + "\r\n"
with io.open(DST, "w", encoding="utf-8-sig", newline="") as f:
    f.write(text)
print("wrote", DST, "({} lines)".format(len(out)))
