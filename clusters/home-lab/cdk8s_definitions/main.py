#!/usr/bin/env python

import cdk8s_plus_27 as kplus
import yaml
from cdk8s import App, Chart, Names, ApiObject, Helm, Yaml, JsonPatch
from constructs import Construct

from imports.io.fluxcd.toolkit.kustomize import (
    Kustomization,
    KustomizationSpecSourceRefKind,
    KustomizationSpecDecryptionProvider,
)

KUSTOMIZE_API_VERSION = "kustomize.config.k8s.io/v1beta1"


def helm_repo(repo_name):
    with open(f"../helmrepos/{repo_name}.yaml", "r") as helm_repo_file:
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
    def __init__(self, scope, identifier, **kwargs):
        super().__init__(scope=scope, id=identifier, disable_resource_name_hashes=True)
        Kustomization(self, f"{identifier}-kustomization", **kwargs)


class HelmApp(App):
    def __init__(self, name, values_dir, **kwargs):
        with open(f"{values_dir}/{name}.yaml", "r") as helm_release_file:
            helm_release = yaml.safe_load(helm_release_file)
            namespace = helm_release["spec"]["targetNamespace"]

            self.name = name
            self.namespace = namespace

            super().__init__(outdir=f"dist/{namespace}/{name}")

            with open(f"{values_dir}/{name}-values.yaml", "r") as values_file:
                values = yaml.safe_load(values_file)

                HelmChart(
                    scope=self,
                    identifier=name,
                    chart=helm_release["spec"]["chart"]["spec"]["chart"],
                    values=values,
                    version=helm_release["spec"]["chart"]["spec"]["version"],
                    repo=helm_repo(
                        helm_release["spec"]["chart"]["spec"]["sourceRef"]["name"]
                    ),
                    namespace=namespace,
                    **kwargs,
                )

            KustomizationChart(
                scope=self,
                identifier=f"{name}-flux-kustomization",
                metadata={"namespace": "flux-system", "name": f"{name}-{namespace}"},
                spec={
                    "interval": "10m0s",
                    "path": f"./clusters/home-lab/cdk8s_definitions/dist/{namespace}/{name}",
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
            file_path=f"dist/{self.namespace}/{self.name}/kustomization.yaml",
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
        values_dir="../media",
    ),
    HelmApp(
        name="radarr",
        values_dir="../media",
    ),
    HelmApp(
        name="sonarr",
        values_dir="../media",
    ),
    HelmApp(
        name="bazarr",
        values_dir="../media",
    ),
    HelmApp(
        name="jackett",
        values_dir="../media",
    ),
    HelmApp(
        name="jellyfin",
        values_dir="../media",
    ),
    HelmApp(
        name="prowlarr",
        values_dir="../media",
    ),
    HelmApp(
        name="qbittorrent",
        values_dir="../media",
    ),
    HelmApp(
        name="external-service",
        values_dir="../infra",
    ),
    HelmApp(
        name="vault",
        values_dir="../infra",
    ),
    HelmApp(
        name="pihole",
        values_dir="../infra",
    ),
    HelmApp(
        name="kube-vip",
        values_dir="../infra",
    ),
    HelmApp(
        name="datadog",
        values_dir="../infra",
    ),
    HelmApp(
        name="cert-manager",
        values_dir="../infra",
    ),
    HelmApp(
        name="home-assistant",
        values_dir="../iot",
    ),
    HelmApp(
        name="cloudnative-pg",
        values_dir="../cloudnative-pg",
    ),
    HelmApp(
        name="external-service",
        values_dir="../aphorya/prod",
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
                f"dist/{app.namespace}/{app.get_name()}/{app.get_name()}-flux-kustomization.k8s.yaml"
                for app in apps
            ],
        }
    ],
)
