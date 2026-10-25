#!/usr/bin/env python3
"""Render every Argo CD app from its ApplicationSet into <out>/<app>.yaml.

Usage: argocd-render.py <repo-root> <out-dir>
Secret values are redacted so chart-generated passwords never reach CI logs.
Charts are pulled once into $CHART_CACHE (default: a temp dir) and rendered from there.
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

import yaml

OWN_REPO = "https://github.com/St0rmingBr4in/home-kube-flux-config"
PLACEHOLDER = re.compile(r"\{\{\s*(\w+)\s*\}\}")
# The Datadog chart stamps a fresh id/time on every render; pin them so diffs stay quiet.
# LibYAML's C parser: the pure-Python one is ~8x slower, and CI nodes have slow vCPUs.
LOADER, DUMPER = yaml.CSafeLoader, yaml.CSafeDumper
NOISE = re.compile(r"^(\s*install_(?:id|time): ).*$", re.M)


def apps(root):
    for f in sorted(root.glob("argocd/**/applicationset.yaml")):
        for doc in yaml.safe_load_all(f.read_text()):
            if not doc or doc.get("kind") != "ApplicationSet":
                continue
            template = json.dumps(doc["spec"]["template"])
            for gen in doc["spec"]["generators"]:
                for el in gen["list"]["elements"]:
                    yield json.loads(PLACEHOLDER.sub(lambda m: str(el[m.group(1)]), template))


def run(cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def chart(s, cache):
    # Chart versions are immutable, so a cached download stays valid.
    d = cache / re.sub(r"\W", "_", s["repoURL"]) / s["chart"] / s["targetRevision"]
    found = list(d.glob("*.tgz"))
    if not found:
        d.mkdir(parents=True, exist_ok=True)
        run(["helm", "pull", s["chart"], "--repo", s["repoURL"], "--version", s["targetRevision"], "-d", str(d)])
        found = list(d.glob("*.tgz"))
    return str(found[0])


def render(root, app, kube_version, cache):
    spec = app["spec"]
    sources = spec.get("sources") or [spec["source"]]
    refs = {s["ref"]: root for s in sources if "ref" in s}
    out = []
    for s in sources:
        if "chart" in s:
            cmd = ["helm", "template", app["metadata"]["name"], chart(s, cache),
                   "--namespace", spec["destination"]["namespace"],
                   "--kube-version", kube_version, "--include-crds"]
            helm = s.get("helm", {})
            for vf in helm.get("valueFiles", []):
                ref, _, rel = vf.partition("/")
                cmd += ["-f", str(refs[ref.lstrip("$")] / rel)]
            with tempfile.NamedTemporaryFile("w", suffix=".yaml") as values:
                values.write(helm.get("values", ""))
                values.flush()
                out.append(run(cmd + ["-f", values.name]))
        elif "path" in s:
            assert s["repoURL"] == OWN_REPO, s["repoURL"]
            out.append(run(["kustomize", "build", str(root / s["path"])]))
    return "---\n".join(out)


def redact(manifest):
    docs = [d for d in yaml.load_all(manifest, Loader=LOADER) if d]
    for d in docs:
        if d.get("kind") == "Secret":
            for field in ("data", "stringData"):
                for k in d.get(field) or {}:
                    d[field][k] = "<redacted>"
    return NOISE.sub(r"\1<render-time>", yaml.dump_all(docs, Dumper=DUMPER, sort_keys=False))


def main(root, out):
    root, out = pathlib.Path(root).resolve(), pathlib.Path(out)
    out.mkdir(parents=True, exist_ok=True)
    k3s = yaml.safe_load((root / "ansible/inventory/group_vars/k3s_cluster/vars.yaml").read_text())
    kube_version = re.match(r"v?(\d+\.\d+\.\d+)", k3s["k3s_release_version"]).group(1)
    cache = pathlib.Path(os.environ.get("CHART_CACHE") or tempfile.mkdtemp())

    def one(app):
        name = app["metadata"]["name"]
        try:
            (out / f"{name}.yaml").write_text(redact(render(root, app, kube_version, cache)))
            return None
        except subprocess.CalledProcessError as e:
            return f"{name}: {' '.join(e.cmd[:3])} failed\n{e.stderr}"

    with ThreadPoolExecutor(8) as pool:
        errors = [e for e in pool.map(one, apps(root)) if e]
    for e in errors:
        print(e, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
