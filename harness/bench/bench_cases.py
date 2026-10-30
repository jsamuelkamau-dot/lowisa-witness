# bench_cases.py: writes one page spec per benchmark paper (synthetic students, not real data) and cases.json with
# each paper's sitting (as the teacher sets it) and the truth for every question.
#   truth: mastered | right_answer_wrong_thinking | part_way | not_yet; "no_working" = only an answer was written
import json, pathlib
B = pathlib.Path(r"C:\lw-witness-scratch\bench")
M, R, P, N = "mastered", "right_answer_wrong_thinking", "part_way", "not_yet"

CASES = [
 dict(id="long_maths_en", level="Year 8 maths", head="End of term test      Name: Grace",
  qs=["Find 20% of 45", "Solve 3x + 4 = 19", "Simplify 18/24", "Work out 2/5 + 1/10", "Expand 4(x - 3)",
      "Find the mean of 3, 7, 8, 10", "Area of a 5 cm by 8 cm rectangle", "Work out 0.4 × 0.3", "Solve x/4 = 6", "Write 3/8 as a decimal"],
  ans=[["45 × 20 ÷ 100 = 9"], ["3x = 19 − 4", "3x = 15", "x = 5"], ["18/24 = 3/4  (÷6)"], ["2/5 + 1/10 = 3/15"],
       ["4x − 12"], ["3 + 7 + 8 + 10 = 28", "28 ÷ 4 = 7"], ["A = 5 + 8 = 13 cm²"], ["0.4 × 0.3 = 0.12"],
       [{"t": "x = 6 ÷ 4", "strike": "all"}, "x = 6 × 4 = 24"], ["3 ÷ 8 = 0.375"]],
  truth=["mastered", "mastered", "mastered", "not_yet", "mastered", "mastered", "not_yet", "mastered", "mastered", "mastered"],
  sheet=False, ink=32, step=52, gap=6),
 dict(id="maths_strong_en", level="Year 8 maths", head="Maths check      Name: Amara",
  qs=["Find 15% of 60", "Solve 2x + 3 = 11", "Simplify 12/18"],
  ans=[["60 × 15 ÷ 100", "= 9"], ["2x = 11 − 3", "2x = 8", "x = 4"], ["12/18 = 2/3  (÷6)"]], truth=[M, M, M]),
 dict(id="maths_cancel_en", level="Year 7 maths", head="Fractions check      Name: Tom",
  qs=["Simplify 16/64", "Work out 1/2 + 1/4", "Work out 2/3 + 1/4"],
  ans=[["16/64 = 1/4  (the 6s cancel)"], ["1/2 = 2/4", "2/4 + 1/4 = 3/4"], ["2/3 + 1/4 = 3/7"]], truth=[R, M, N]),
 dict(id="maths_selfcorrect_en", level="Year 9 maths", head="Algebra quiz      Name: Lina",
  qs=["Expand 3(x + 4)", "Solve 5x − 2 = 18", "Find the mean of 4, 6 and 11"],
  ans=[[{"t": "3x + 4", "strike": "all"}, "3x + 12"], ["5x = 18 + 2", "5x = 20", "x = 4"], ["4 + 6 + 11 = 21", "21 ÷ 3 = 7"]],
  truth=[M, M, M]),
 dict(id="answers_only_en", level="Grade 9 physics", head="Physics quiz      Name: Sam",
  qs=["A car travels 120 km in 1.5 h. What is its average speed?", "F = ma. Find F when m = 2 kg and a = 2 m/s²", "Convert 5 m/s to km/h"],
  scheme="Q1: 1 for speed = distance / time, 1 for 80 km/h. Q2: 1 for multiplying m by a, 1 for 4 N. Q3: 1 for a correct conversion, 1 for 18 km/h. Working must be shown for the method mark.",
  ans=[["80 km/h"], ["4 N"], ["18 km/h"]], truth=["no_working", "no_working", "no_working"]),
 dict(id="chem_en", level="Grade 10 chemistry", head="Chemistry test      Name: Kwame",
  qs=["Balance: H2 + O2 → H2O", "How many moles in 36 g of water (M = 18 g/mol)?", "2 mol of salt in 500 mL. Concentration in mol/L?"],
  ans=[["2H2 + O2 → 2H2O"], ["n = m ÷ M", "n = 36 ÷ 18 = 2 mol"], ["c = n ÷ V", "c = 2 ÷ 500 = 0.004 mol/L"]], truth=[M, M, N]),
 dict(id="bio_short_en", level="Year 8 science", head="Science check      Name: Priya",
  qs=["Why do green plants need sunlight?", "What does the heart do?", "Which gas do we breathe out more of?"],
  ans=[["For photosynthesis: light energy", "makes glucose from CO2 + water"], ["It cleans the blood"], [{"t": "Oxygen", "strike": "all"}, "Carbon dioxide"]],
  truth=[M, N, M]),
 dict(id="fr_maths", level="Collège, 5e", head="Contrôle de maths      Nom : Léa",
  qs=["Calcule les 3/4 de 20", "Résous 2x + 3 = 11", "Périmètre d'un carré de côté 4 cm"],
  ans=[["20 ÷ 4 = 5", "5 × 3 = 15"], ["2x = 11 + 3 = 14", "x = 7"], ["P = 4 × 4 = 16 cm  (côté × côté)"]], truth=[M, N, R]),
 dict(id="sw_maths", level="Darasa la 7, hesabu", head="Mtihani wa hesabu      Jina: Juma",
  qs=["Tafuta 10% ya 300", "Zidisha 0.3 × 0.2", "Tafuta wastani wa 4, 6 na 8"],
  ans=[["300 ÷ 10 = 30"], ["0.3 × 0.2 = 0.6"], ["4 + 6 + 8 = 18", "18 ÷ 3 = 6"]], truth=[M, N, M]),
 dict(id="ar_maths", level="الصف السابع، رياضيات", head="اختبار الرياضيات      الاسم: سارة", rtl_head=True,
  qs=["احسب 15% من 200", "حل المعادلة: x + 7 = 12", "مساحة مثلث قاعدته 6 سم وارتفاعه 4 سم"],
  ans=[["200 × 15 ÷ 100 = 30"], ["x = 12 + 7 = 19"], [{"t": "المساحة = 6 × 4 = 24 سم²", "rtl": True}]], truth=[M, N, N]),
 dict(id="hi_maths", level="कक्षा 7, गणित", head="गणित परीक्षा      नाम: रवि",
  qs=["25 का 20% ज्ञात करो", "3² + 4² का मान", "एक बस 1 घंटे में 60 किमी चलती है। 3 घंटे में कितनी?"],
  ans=[["25 × 20 ÷ 100 = 5"], ["3² + 4² = (3 + 4)² = 49"], ["60 × 3 = 180 किमी"]], truth=[M, N, M]),
]

def qlines(qs):
    return [f"{i+1}. {q}" for i, q in enumerate(qs)]

def spec(case, out_html):
    # sheet=False: the questions are on a separate question sheet, only the answers on this one
    ql = qlines(case["qs"]) if case.get("sheet", True) else []
    step, gap = case.get("step", 70), case.get("gap", 20)
    y = 150 + 35 * len(ql) + 45
    t = 1.0
    items = []
    for qi, lines in enumerate(case["ans"]):
        items.append([round(t, 2), 0.5, "t", 60, y, f"{qi+1}."]); t += 0.6
        for ln in lines:
            ln = ln if isinstance(ln, dict) else {"t": ln}
            du = max(1.2, 0.13 * len(ln["t"]))
            it = [round(t, 2), round(du, 2), "t", 110, y, ln["t"]] + (["rtl"] if ln.get("rtl") else [])
            items.append(it); t += du + 0.6
            if ln.get("strike"):
                n = len(ln["t"]) if ln["strike"] == "all" else ln["strike"]
                items.append([round(t, 2), 0.6, "x", len(items) - 1, n]); t += 1.0
            y += step; t += 0.8
        t += 2.0; y += gap
    return {"out": out_html, "head": case["head"], "qlines": ql, "items": items, "sway": case.get("sway", 3), "ink": case.get("ink", 40)}, t + 3.0

out = []
for c in CASES:
    s, secs = spec(c, str(B / f"{c['id']}.html"))
    (B / f"{c['id']}_spec.json").write_text(json.dumps(s, ensure_ascii=False), encoding="utf-8")
    sitting = {"level": c["level"], "kind": "paper",
               "questions": [{"n": i + 1, "text": q, "marks": 2} for i, q in enumerate(c["qs"])]}
    if c.get("scheme"): sitting["scheme"] = c["scheme"]
    out.append({"id": c["id"], "secs": round(secs, 1), "sitting": sitting, "truth": c["truth"]})
(B / "cases.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(out), "cases", [(o["id"], o["secs"]) for o in out])
