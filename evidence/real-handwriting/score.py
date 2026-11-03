#!/usr/bin/env python3
"""Recompute every real-handwriting number in the README from the committed result files.

    python3 evidence/real-handwriting/score.py

Against the class teacher's own marks: agreement, the teacher's wrong answers the product also marked wrong (recall),
answers it marked wrong that the teacher marked right, Cohen's kappa, and the all-right baseline (the agreement a marker
would get by marking every answer right). Science question 20 is left out: the teacher's mark on it is unclear. The written-answer papers
(results/written-answers-3-runs.json) are scored the same way.

Where a file records it, each run also prints what happened to the answers Witness did not accept: how many had a wrong
idea named to the student, and how many were held for Lo to ask first. Each set then prints the same counts by QUESTION
over its runs (a question counted once, not once per run), with 95% intervals over questions.
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def score(rows):
    n = len(rows)
    agree = sum(r['right'] == r['teacher_right'] for r in rows)
    t_wrong = [r for r in rows if not r['teacher_right']]
    caught = sum(not r['right'] for r in t_wrong)
    false_wrong = sum((not r['right']) and r['teacher_right'] for r in rows)
    # Cohen's kappa over the two labels, right and wrong
    p_o = agree / n
    pr_t = sum(r['teacher_right'] for r in rows) / n
    pr_p = sum(r['right'] for r in rows) / n
    p_e = pr_t * pr_p + (1 - pr_t) * (1 - pr_p)
    kappa = (p_o - p_e) / (1 - p_e) if p_e < 1 else float('nan')
    return {'questions': n, 'agree': agree, 'teacher_wrong': len(t_wrong), 'caught': caught, 'false_wrong': false_wrong,
            'kappa': round(kappa, 2), 'all_right_baseline': f'{n - len(t_wrong)}/{n}',
            'recall_95ci': wilson(caught, len(t_wrong))}


def wilson(k, n, z=1.96):
    if n == 0:
        return None
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return [max(0.0, round(c - h, 2)), min(1.0, round(c + h, 2))]


def scored(subject_rows):
    return [r for r in subject_rows if r.get('teacher_right') is not None]


def line(name, rows_by_subject):
    subjects = list(rows_by_subject)
    allrows = [r for s in subjects for r in scored(rows_by_subject[s])]
    s = score(allrows)
    per = '  '.join(f'{x} {score(scored(rows_by_subject[x]))["agree"]}/{len(scored(rows_by_subject[x]))}' for x in subjects)
    print(f'{name:44} {s["agree"]}/{s["questions"]} agree; caught {s["caught"]}/{s["teacher_wrong"]} '
          f'(95% CI {s["recall_95ci"]}); {s["false_wrong"]} marked wrong that the teacher marked right; '
          f'kappa {s["kappa"]}; all-right baseline {s["all_right_baseline"]}   [{per}]')
    return s


def held(name, rows_by_subject):
    rows = [r for s in rows_by_subject for r in scored(rows_by_subject[s])]
    if not rows or 'idea_named' not in rows[0]:
        return
    out = [r for r in rows if not r['right']]
    named = [r for r in out if r.get('idea_named')]
    asks = [r for r in out if not r.get('idea_named') and 'Lo asks' in (r.get('diagnosis') or '')]
    print(f'{"":44} not accepted {len(out)}: a wrong idea named {len(named)}, held for Lo to ask {len(asks)}')


def by_question(name, runs):
    """One row per question over all runs of a set."""
    qs = {}
    for run in runs:
        for subj, rows in run['papers'].items():
            for r in scored(rows):
                qs.setdefault((subj, r['n']), []).append(r)
    n = len(qs)
    always = sum(all(r['right'] == r['teacher_right'] for r in v) for v in qs.values())
    never = sum(all(r['right'] != r['teacher_right'] for r in v) for v in qs.values())
    t_wrong = [v for v in qs.values() if not v[0]['teacher_right']]
    caught_all = sum(all(not r['right'] for r in v) for v in t_wrong)
    print(f'{name + " by question":44} {n} questions: agree in every run {always}, in no run {never}, in some runs {n - always - never}; '
          f"teacher's wrong answers caught in every run"
          f' {caught_all}/{len(t_wrong)} (95% CI {wilson(caught_all, len(t_wrong))})')
    if 'idea_named' in runs[0]['papers'][next(iter(runs[0]['papers']))][0]:
        out = [v for v in qs.values() if any(not r['right'] for r in v)]
        named = [v for v in out if any(r.get('idea_named') for r in v if not r['right'])]
        print(f'{"":44} questions not accepted in some run {len(out)}: a wrong idea named in some run {len(named)} '
              f'(95% CI {wilson(len(named), len(out))})')


def main():
    two = json.load(open(os.path.join(HERE, 'results', 'three-papers-two-conditions.json')))
    for name, rows in two['conditions'].items():
        line(name, rows)
    c_path = os.path.join(HERE, 'results', 'condition-c-shipped-code-3-runs.json')
    if os.path.exists(c_path):
        c = json.load(open(c_path, encoding='utf-8'))
        for run in c['runs']:
            line(f'C_shipped_code run {run["run"]}', run['papers'])
            held('', run['papers'])
        by_question('C_shipped_code', c['runs'])
    w_path = os.path.join(HERE, 'results', 'written-answers-3-runs.json')
    if os.path.exists(w_path):
        w = json.load(open(w_path, encoding='utf-8'))
        for run in w['runs']:
            line(f'Written answers run {run["run"]}', run['papers'])
            held('', run['papers'])
        by_question('Written answers', w['runs'])
    # 3 Nov: both sets again on the tagged code v1.0-code (two readings must agree before Accept all)
    for name, f in (('C on v1.0-code', 'condition-c-on-v1.0-code-3-runs.json'), ('Written on v1.0-code', 'written-answers-on-v1.0-code-3-runs.json')):
        path = os.path.join(HERE, 'results', f)
        if os.path.exists(path):
            t = json.load(open(path, encoding='utf-8'))
            for run in t['runs']:
                line(f'{name} run {run["run"]}', run['papers'])
                held('', run['papers'])
            by_question(name, t['runs'])


if __name__ == '__main__':
    main()
