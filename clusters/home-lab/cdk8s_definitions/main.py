#!/usr/bin/env python
import cdk8s_plus_27 as kplus
import yaml
from cdk8s import App, Chart, Names, ApiObject, Helm, Yaml
from constructs import Construct

from imports.io.fluxcd.toolkit.kustomize import (
    Kustomization,
    KustomizationSpecSourceRefKind,
    KustomizationSpecDecryptionProvider,
)

KUSTOMIZE_API_VERSION = "kustomize.config.k8s.io/v1beta1"


def helm_repo(repo_name):
    if repo_name == "truecharts":
        return "https://charts.truecharts.org"


class HelmChart(Chart):
    def __init__(
        self, scope: Construct, identifier: str, repo_name, values_dir, **kwargs
    ):
        super().__init__(scope=scope, id=identifier, disable_resource_name_hashes=True)

        with open(f"{values_dir}/{identifier}-values.yaml", "r") as file:
            values = yaml.safe_load(file)

            Helm(
                self,
                identifier,
                release_name=identifier,
                repo=helm_repo(repo_name),
                chart=identifier,
                values=values,
                **kwargs,
            )


class KustomizationChart(Chart):
    def __init__(self, scope, identifier, **kwargs):
        super().__init__(scope=scope, id=identifier, disable_resource_name_hashes=True)
        Kustomization(self, f"{identifier}-kustomization", **kwargs)


class HelmApp(App):
    def __init__(self, name, namespace, **kwargs):
        super().__init__(outdir=f"dist/{name}")
        self.name = name

        HelmChart(scope=self, identifier=name, namespace=namespace, **kwargs)
        KustomizationChart(
            scope=self,
            identifier=f"{name}-flux-kustomization",
            metadata={"namespace": "flux-system", "name": name},
            spec={
                "interval": "10m0s",
                "path": f"./clusters/home-lab/cdk8s_definitions/dist/{name}",
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

    def get_name(self):
        return self.name

    def synth(self):
        super().synth()

        Yaml.save(
            file_path=f"dist/{self.name}/kustomization.yaml",
            docs=[
                {
                    "apiVersion": KUSTOMIZE_API_VERSION,
                    "kind": "Kustomization",
                    "resources": [f"{self.name}.k8s.yaml"],
                }
            ],
        )


apps = [
    HelmApp(
        name="flaresolverr",
        repo_name="truecharts",
        version="10.0.5",
        namespace="prod-media",
        values_dir="../media",
    ),
    HelmApp(
        name="radarr",
        repo_name="truecharts",
        version="17.0.7",
        namespace="prod-media",
        values_dir="../media",
    ),
    HelmApp(
        name="sonarr",
        repo_name="truecharts",
        version="16.0.2",
        namespace="prod-media",
        values_dir="../media",
    ),
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
                f"dist/{app.get_name()}/{app.get_name()}-flux-kustomization.k8s.yaml"
                for app in apps
            ],
        }
    ],
)
