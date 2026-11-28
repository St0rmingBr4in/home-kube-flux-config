FROM python:3.14-slim@sha256:f57c4c23b985d95deea5bc5249e2f9c8a512b4cc9d5d3fd31900cbd2f5f0a604
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
