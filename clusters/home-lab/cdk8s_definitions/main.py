#!/usr/bin/env python
import cdk8s_plus_27 as kplus
import cdk8s
import yaml
from cdk8s import App, Chart, Names, ApiObject, Helm
from constructs import Construct


def helm_repo(repo_name):
    if repo_name == "truecharts":
        return "https://charts.truecharts.org"


class HelmChart(Chart):
    def __init__(self, scope: Construct, resource_id: str, repo_name, version, namespace, values_dir):
        super().__init__(scope, resource_id, disable_resource_name_hashes=True)

        with open(f"{values_dir}/{resource_id}-values.yaml", "r") as file:
            values = yaml.safe_load(file)

            Helm(
                self,
                resource_id,
                release_name=resource_id,
                repo=helm_repo(repo_name),
                chart=resource_id,
                version=version,
                values=values,
                namespace=namespace,
            )


app = App(record_construct_metadata=True)

HelmChart(
    scope=app,
    resource_id="flaresolverr",
    repo_name="truecharts",
    version="10.0.5",
    namespace="prod-media",
    values_dir="../media"
)

HelmChart(
    scope=app,
    resource_id="radarr",
    repo_name="truecharts",
    version="17.0.7",
    namespace="prod-media",
    values_dir="../media"
)

HelmChart(
    scope=app,
    resource_id="sonarr",
    repo_name="truecharts",
    version="16.0.2",
    namespace="prod-media",
    values_dir="../media"
)

app.synth()
