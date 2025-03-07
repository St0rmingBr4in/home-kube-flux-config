#!/usr/bin/env python

import cdk8s
import cdk8s_plus_27 as kplus
import yaml
import os
from cdk8s import (
    App,
    Chart,
    Names,
    ApiObject,
    Helm,
    Yaml,
    JsonPatch,
    Include,
    ApiObjectMetadata,
    Size,
    ApiObject,
)
from constructs import Construct

from imports.io.fluxcd.toolkit.kustomize import (
    Kustomization,
    KustomizationSpecSourceRefKind,
    KustomizationSpecDecryptionProvider,
)

from imports.k8s import (
        KubeStorageClass,
        )

KUSTOMIZE_API_VERSION = "kustomize.config.k8s.io/v1beta1"


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


class IncludeChart(Chart):
    def __init__(self, scope: Construct, identifier: str, **kwargs):
        super().__init__(
            scope=scope,
            id=identifier,
            disable_resource_name_hashes=True,
        )
        Include(scope=self, id=identifier, **kwargs)


class KustomizationChart(Chart):
    def __init__(self, scope, identifier, namespace, **kwargs):
        super().__init__(
            scope=scope,
            id=identifier,
            disable_resource_name_hashes=False,
            namespace=namespace,
        )
        Kustomization(self, f"{identifier}-kustomization", **kwargs)

class StorageClassChart(Chart):
    def __init__(self, scope, identifier, **kwargs):
        super().__init__(
            scope=scope,
            id=identifier,
            disable_resource_name_hashes=True,
        )
        KubeStorageClass(
            self,
            "local-storage",
            **kwargs,
        )

class IscsiPersistenceChart(Chart):
    def __init__(self, scope, identifier, namespace, size, **kwargs):
        super().__init__(
            scope=scope,
            id=identifier,
            disable_resource_name_hashes=True,
            namespace=namespace,
        )

        pvc = kplus.PersistentVolumeClaim(
            self,
            "pvc",
            metadata=ApiObjectMetadata(name=identifier),
            access_modes=[
                kplus.PersistentVolumeAccessMode.READ_WRITE_ONCE,
                kplus.PersistentVolumeAccessMode.READ_ONLY_MANY,
            ],
            storage=size,
            volume_mode=kplus.PersistentVolumeMode.FILE_SYSTEM,
        )

        pv = kplus.PersistentVolume(
            self,
            "pv",
            metadata=ApiObjectMetadata(name=identifier),
            access_modes=[
                kplus.PersistentVolumeAccessMode.READ_WRITE_ONCE,
                kplus.PersistentVolumeAccessMode.READ_ONLY_MANY,
            ],
            storage=size,
            volume_mode=kplus.PersistentVolumeMode.FILE_SYSTEM,
            reclaim_policy=kplus.PersistentVolumeReclaimPolicy.RETAIN,
        )

        pv.bind(pvc)

        # Add the iSCSI volume to the PV
        ApiObject.of(pv).add_json_patch(
            JsonPatch.add(
                "/spec/iscsi",
                {
                    "targetPortal": "192.168.42.42",
                    "iqn": f"iqn.2000-01.com.synology:{identifier}",
                    "lun": 1,
                    "fsType": "ext4",
                },
            )
        )

        # PVs are not namespaced, so we need to remove the namespace from the PV
        ApiObject.of(pv).add_json_patch(JsonPatch.remove("/metadata/namespace"))

        # Fix the namespace of the PVC claimRef
        ApiObject.of(pv).add_json_patch(
            JsonPatch.add("/spec/claimRef/namespace", namespace)
        )

        ApiObject.of(pvc).add_json_patch(JsonPatch.add("/spec/volumeName", identifier))



class LocalPersistenceChart(Chart):
    def __init__(self, scope, identifier, namespace, size, **kwargs):
        super().__init__(
            scope=scope,
            id=identifier,
            disable_resource_name_hashes=True,
            namespace=namespace,
        )

        pvc = kplus.PersistentVolumeClaim(
            self,
            "pvc",
            metadata=ApiObjectMetadata(name=identifier),
            access_modes=[
                kplus.PersistentVolumeAccessMode.READ_WRITE_ONCE,
                kplus.PersistentVolumeAccessMode.READ_ONLY_MANY,
            ],
            storage=size,
            volume_mode=kplus.PersistentVolumeMode.FILE_SYSTEM,
            storage_class_name="local-storage",
        )

        pv = kplus.PersistentVolume(
            self,
            "pv",
            metadata=ApiObjectMetadata(name=identifier),
            access_modes=[
                kplus.PersistentVolumeAccessMode.READ_WRITE_ONCE,
                kplus.PersistentVolumeAccessMode.READ_ONLY_MANY,
            ],
            storage=size,
            volume_mode=kplus.PersistentVolumeMode.FILE_SYSTEM,
            reclaim_policy=kplus.PersistentVolumeReclaimPolicy.RETAIN,
        )

        pv.bind(pvc)

        # PVs are not namespaced, so we need to remove the namespace from the PV
        ApiObject.of(pv).add_json_patch(JsonPatch.remove("/metadata/namespace"))

        # Add the nodeAffinity to the PVC
        ApiObject.of(pv).add_json_patch(JsonPatch.add("/spec/nodeAffinity", {
            "required": {
                "nodeSelectorTerms": [
                    {
                        "matchExpressions": [
                            {
                                "key": "kubernetes.io/hostname",
                                "operator": "In",
                                "values": [
                                    "k3s-clusterv2-node1",
                                ]
                            }
                        ]
                    }
                ]
            }
        }))

        # Fix the namespace of the PVC claimRef
        ApiObject.of(pv).add_json_patch(
            JsonPatch.add("/spec/claimRef/namespace", namespace)
        )

        ApiObject.of(pvc).add_json_patch(JsonPatch.add("/spec/volumeName", identifier))

        # Add the local volume to the PV
        ApiObject.of(pv).add_json_patch(
            JsonPatch.add(
                "/spec/local",
                {"path": f"/var/lib/local-volumes/{identifier}"},
            )
        )


class FluxApp(App):
    def __init__(self, name, namespace, root_dir=None, additionnal_objs=[], **kwarg):
        self.name = name
        self.namespace = namespace
        self.root_dir = root_dir
        super().__init__(outdir=os.path.join("dist", namespace, name), **kwarg)

        KustomizationChart(
            scope=self,
            identifier=chart_flux_kustomization_name(self),
            namespace="flux-system",
            spec={
                "interval": "10m0s",
                "path": os.path.join(
                    "./clusters/home-lab/cdk8s_definitions", self.dist_dir()
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

        for o in additionnal_objs:
            IncludeChart(
                scope=self,
                identifier=o.removesuffix(".yaml"),
                url=os.path.join(root_dir, o),
            )

    def synth(self):
        super().synth()

        Yaml.save(
            file_path=os.path.join(self.dist_dir(), "kustomization.yaml"),
            docs=[
                {
                    "apiVersion": KUSTOMIZE_API_VERSION,
                    "kind": "Kustomization",
                    "resources": [
                        f"{c.node.id}.k8s.yaml"
                        for c in self.charts
                        if not isinstance(c, KustomizationChart)
                    ],
                }
            ],
        )

    def dist_dir(self):
        return os.path.join("dist", self.namespace, self.name)


class TrueChartsApp(FluxApp):
    def __init__(
        self,
        name,
        namespace,
        version,
        values,
        channel="stable",
        create_claim=[],
        **kwargs,
    ):
        super().__init__(name=name, namespace=namespace, **kwargs)

        HelmChart(
            scope=self,
            identifier=name,
            version=version,
            chart=f"oci://tccr.io/truecharts/{name}",
            namespace=namespace,
            values=values,
            **kwargs,
        )

        for claim in create_claim:
            LocalPersistenceChart(
                scope=self,
                identifier=claim.name,
                namespace=namespace,
                size=claim.size,
            )


class HelmApp(FluxApp):
    def __init__(self, name, root_dir, **kwargs):
        with open(os.path.join(root_dir, f"{name}.yaml"), "r") as helm_release_file:
            helm_release = yaml.safe_load(helm_release_file)
            namespace = helm_release["spec"]["targetNamespace"]

            super().__init__(
                name=name, namespace=namespace, root_dir=root_dir, **kwargs
            )

            with open(
                os.path.join(root_dir, f"{name}-values.yaml"), "r"
            ) as values_file:
                values = yaml.safe_load(values_file)

                chart = helm_release["spec"]["chart"]["spec"]["chart"]
                repo = helm_repo(
                    helm_release["spec"]["chart"]["spec"]["sourceRef"]["name"]
                )

                if chart == "./traefik":
                    chart = "/Users/julien.doche/Documents/git-repos/traefik-helm-chart/traefik"
                    repo = ""
                else:
                    if repo.startswith("oci"):
                        chart = repo + "/" + chart
                        print(f"chart: {chart}")
                        repo = None

                HelmChart(
                    scope=self,
                    identifier=name,
                    chart=chart,
                    values=values,
                    version=helm_release["spec"]["chart"]["spec"]["version"],
                    repo=repo,
                    namespace=namespace,
                )


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


class NamespacesApp(FluxApp):
    def __init__(self, namespaces):
        super().__init__(name="namespaces", namespace="flux-system")

        chart = Chart(
            scope=self,
            id="namespaces",
            disable_resource_name_hashes=True,
        )

        for namespace in namespaces:
            namespace = kplus.Namespace(
                chart, namespace, metadata=ApiObjectMetadata(name=namespace)
            )

class LocalStorageClassApp(FluxApp):
    def __init__(self):
        super().__init__(name="local-storage-class", namespace="default")

        StorageClassChart(
            self,
            "local-storage",
            metadata={"name":"local-storage"},
            provisioner="kubernetes.io/no-provisioner",
            volume_binding_mode="WaitForFirstConsumer",
        )



class Claim:
    def __init__(self, name: str, size: cdk8s.Size):
        self.name = name
        self.size = size


apps = [
    LocalStorageClassApp(),
    NamespacesApp(
        namespaces=[
            "prod-infra",
            "prod-media",
            "prod-iot",
            "prod-aphorya",
            "renovate",
        ]
    ),
    HelmApp(
        name="dynmap-db",
        root_dir="../aphorya",
        additionnal_objs=["dynmap-db-secret.yaml"],
    ),
    FluxApp(
        name="basicauth-traefik-secret",
        namespace="prod-media",
        root_dir="../media/",
        additionnal_objs=["basicauth-traefik-secret.yaml"],
    ),
    HelmApp(
        name="renovate",
        root_dir="../renovate",
        additionnal_objs=["renovate-secret.yaml"],
    ),
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
        name="jellyseerr",
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
        additionnal_objs=["datadog-cluster-agent-secret.yaml", "datadog-secret.yaml"],
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
        name="external-service",
        root_dir="../aphorya",
    ),
    HelmApp(
        name="minecraft-aphorya",
        root_dir="../aphorya",
        additionnal_objs=["minecraft-aphorya-rcon-secret.yaml"],
    ),
    CertificateApp(name="st0rmingbr4in-com"),
    CertificateApp(name="aphorya-fr"),
    HelmApp(
        name="external-service",
        root_dir="../rakk0o-dev",
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
                os.path.join(app.dist_dir(), chart_flux_kustomization_file(app))
                for app in apps
            ],
        }
    ],
)
