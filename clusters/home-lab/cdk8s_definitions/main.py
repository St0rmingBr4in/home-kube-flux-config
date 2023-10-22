#!/usr/bin/env python

import cdk8s_plus_27 as kplus
import yaml
import os
from cdk8s import App, Chart, Names, ApiObject, Helm, Yaml, JsonPatch, Include
from constructs import Construct

from imports.io.fluxcd.toolkit.kustomize import (
    Kustomization,
    KustomizationSpecSourceRefKind,
    KustomizationSpecDecryptionProvider,
)

KUSTOMIZE_API_VERSION = "kustomize.config.k8s.io/v1beta1"


def app_dist_dir(app):
    return os.path.join("dist", app.namespace, app.name)


def chart_flux_kustomization_name(app):
    return f"{app.name}-{app.namespace}-flux-kustomization"


def chart_flux_kustomization_file(app):
    return f"{chart_flux_kustomization_name(app)}.k8s.yaml"


def helm_repo(repo_name):
    with open(os.path.join("../helmrepos", f"{repo_name}.yaml"), "r") as helm_repo_file:
        helm_repo = yaml.safe_load(helm_repo_file)
        return helm_repo["spec"]["url"]


class HelmChart(Chart):
    def __init__(self, scope: Construct, identifier: str, namespace, **kwargs):
        super().__init__(
            scope=scope,
            id=identifier,
            disable_resource_name_hashes=True,
            namespace=namespace,
        )

        helm = Helm(
            self,
            identifier,
            release_name=identifier,
            namespace=namespace,
            **kwargs,
        )

        for o in helm.api_objects:
            if o.kind == "Deployment":
                met = o.to_json()["spec"]["template"]["metadata"]
                if "annotations" in met and "rollme" in met["annotations"]:
                    o.add_json_patch(
                        JsonPatch.remove("/spec/template/metadata/annotations/rollme")
                    )


class KustomizationChart(Chart):
    def __init__(self, scope, identifier, namespace, **kwargs):
        super().__init__(
            scope=scope,
            id=identifier,
            disable_resource_name_hashes=False,
            namespace=namespace,
        )
        Kustomization(self, f"{identifier}-kustomization", **kwargs)


class FluxApp(App):
    def __init__(self, name, namespace, **kwarg):
        self.name = name
        self.namespace = namespace
        super().__init__(outdir=os.path.join("dist", namespace, name), **kwarg)

        KustomizationChart(
            scope=self,
            identifier=chart_flux_kustomization_name(self),
            namespace="flux-system",
            spec={
                "interval": "10m0s",
                "path": os.path.join(
                    "./clusters/home-lab/cdk8s_definitions", app_dist_dir(self)
                ),
                "prune": True,
                "decryption": {
                    "provider": KustomizationSpecDecryptionProvider.SOPS,
                    "secret_ref": {"name": "sops-gpg"},
                },
                "source_ref": {
                    "kind": KustomizationSpecSourceRefKind.GIT_REPOSITORY,
                    "name": "flux-system",
                },
            },
        )

    def synth(self):
        super().synth()

        Yaml.save(
            file_path=os.path.join(app_dist_dir(self), "kustomization.yaml"),
            docs=[
                {
                    "apiVersion": KUSTOMIZE_API_VERSION,
                    "kind": "Kustomization",
                    "resources": [f"{self.name}.k8s.yaml"],
                }
            ],
        )


class HelmApp(FluxApp):
    def __init__(self, name, root_dir, additionnal_objs=[], **kwargs):
        with open(os.path.join(root_dir, f"{name}.yaml"), "r") as helm_release_file:
            helm_release = yaml.safe_load(helm_release_file)
            namespace = helm_release["spec"]["targetNamespace"]

            super().__init__(name=name, namespace=namespace)

            with open(
                os.path.join(root_dir, f"{name}-values.yaml"), "r"
            ) as values_file:
                values = yaml.safe_load(values_file)

                chart=helm_release["spec"]["chart"]["spec"]["chart"]
                repo=helm_repo(
                    helm_release["spec"]["chart"]["spec"]["sourceRef"]["name"]
                )

                if chart == "./traefik":
                    chart = "/Users/julien.doche/Documents/git-repos/traefik-helm-chart/traefik"
                    repo = ""

                HelmChart(
                    scope=self,
                    identifier=name,
                    chart=chart,
                    values=values,
                    version=helm_release["spec"]["chart"]["spec"]["version"],
                    repo=repo,
                    namespace=namespace,
                    **kwargs,
                )
        for o in additionnal_objs:
            Include(scope=self, id=o, url=os.path.join(root_dir, o))


class CertificateApp(FluxApp):
    def __init__(self, name):
        namespace = "prod-infra"
        super().__init__(name=name, namespace=namespace)

        chart = Chart(
            scope=self,
            id=name,
            disable_resource_name_hashes=True,
            namespace=namespace,
        )
        Include(
            scope=chart,
            id=f"{name}-certificate",
            url=os.path.join("../infra", f"{name}-certificate.yaml"),
        )


apps = [
    HelmApp(
        name="traefik",
        root_dir="../infra",
    ),
    HelmApp(
        name="flaresolverr",
        root_dir="../media",
    ),
    HelmApp(
        name="radarr",
        root_dir="../media",
    ),
    HelmApp(
        name="sonarr",
        root_dir="../media",
    ),
    HelmApp(
        name="bazarr",
        root_dir="../media",
    ),
    HelmApp(
        name="jackett",
        root_dir="../media",
    ),
    HelmApp(
        name="jellyfin",
        root_dir="../media",
    ),
    HelmApp(
        name="prowlarr",
        root_dir="../media",
    ),
    HelmApp(
        name="qbittorrent",
        root_dir="../media",
    ),
    HelmApp(
        name="external-service",
        root_dir="../infra",
    ),
    HelmApp(
        name="vault",
        root_dir="../infra",
    ),
    HelmApp(
        name="pihole",
        root_dir="../infra",
    ),
    HelmApp(
        name="kube-vip",
        root_dir="../infra",
    ),
    HelmApp(
        name="datadog",
        root_dir="../infra",
    ),
    HelmApp(
        name="cert-manager",
        root_dir="../infra",
    ),
    HelmApp(
        name="home-assistant",
        root_dir="../iot",
    ),
    HelmApp(
        name="cloudnative-pg",
        root_dir="../cloudnative-pg",
    ),
    HelmApp(
        name="external-service",
        root_dir="../aphorya/prod",
    ),
    CertificateApp(name="st0rmingbr4in-com"),
    CertificateApp(name="aphorya-fr"),
]

for app in apps:
    app.synth()

Yaml.save(
    file_path="kustomization.yaml",
    docs=[
        {
            "apiVersion": KUSTOMIZE_API_VERSION,
            "kind": "Kustomization",
            "resources": [
                os.path.join(app_dist_dir(app), chart_flux_kustomization_file(app))
                for app in apps
            ],
        }
    ],
)
