FROM python:3.14-slim@sha256:35caba83af2fe6da9a5d922f9b0156f21d1246a48278c58a08bd253303ba42e8
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      git openssh-client curl jq \
    && rm -rf /var/lib/apt/lists/*

# Pin pip tool versions — update ci/images/ci-ansible/requirements.txt to upgrade
COPY ci/images/ci-ansible/requirements.txt /tmp/pip-requirements.txt
RUN pip install --no-cache-dir -r /tmp/pip-requirements.txt

# Pre-bake galaxy roles and collections — rebuild image when ansible/requirements.yml changes
COPY ansible/requirements.yml /tmp/ansible-requirements.yml
RUN ansible-galaxy role install -r /tmp/ansible-requirements.yml \
    && ansible-galaxy collection install -r /tmp/ansible-requirements.yml
