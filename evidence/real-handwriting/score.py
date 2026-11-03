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

The teacher's work: for the latest code, each run also prints how many marks Muse Spark was sure of (confidence 0.9
or more: the desk's "Accept all"), how many of those disagree with the teacher, and how many the teacher checks one by
one. The latest code prints first; earlier code follows, labelled.
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


ACCEPT_ALL = 0.9  # witness_mark ?ACCEPT_ALL: marks at or above it join "Accept all" on the desk


def teacher_work(rows_by_subject):
    rows = [r for s in rows_by_subject for r in scored(rows_by_subject[s])]
    if not rows or 'confidence' not in rows[0]:
        return
    sure = [r for r in rows if (r.get('confidence') or 0) >= ACCEPT_ALL]
    wrong_right = sum(r['right'] and not r['teacher_right'] for r in sure)
    right_wrong = sum((not r['right']) and r['teacher_right'] for r in sure)
    print(f'{"":44} "Accept all" {len(sure)}/{len(rows)} (disagree with the teacher {wrong_right + right_wrong}: '
          f'{wrong_right} marked right that the teacher marked wrong, {right_wrong} the other way); '
          f'the teacher checks {len(rows) - len(sure)} one by one')


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


def run_set(name, f, work=False):
    path = os.path.join(HERE, 'results', f)
    if not os.path.exists(path):
        return
    t = json.load(open(path, encoding='utf-8'))
    for run in t['runs']:
        line(f'{name} run {run["run"]}', run['papers'])
        held('', run['papers'])
        if work:
            teacher_work(run['papers'])
    by_question(name, t['runs'])


def main():
    # The latest results: both sets on v1.0.1-code, three runs each (3-4 Nov). The edge now runs v1.0.2-code, which
    # changes only when two readings count as the same answer; these sets have not been run on it yet.
    print('== Latest: v1.0.1-code ==')
    run_set('C on v1.0.1-code', 'condition-c-on-v1.0.1-code-3-runs.json', work=True)
    run_set('Written on v1.0.1-code', 'written-answers-on-v1.0.1-code-3-runs.json', work=True)
    print('== Earlier code ==')
    two = json.load(open(os.path.join(HERE, 'results', 'three-papers-two-conditions.json')))
    for name, rows in two['conditions'].items():
        line(name, rows)
    run_set('C_shipped_code (e9fb96f)', 'condition-c-shipped-code-3-runs.json')
    run_set('Written answers (e9fb96f)', 'written-answers-3-runs.json')
    # 3 Nov: both sets on the tagged code v1.0-code (two readings must agree before Accept all)
    run_set('C on v1.0-code', 'condition-c-on-v1.0-code-3-runs.json')
    run_set('Written on v1.0-code', 'written-answers-on-v1.0-code-3-runs.json')


if __name__ == '__main__':
    main()
