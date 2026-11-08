FROM python:3.14-slim@sha256:9aaa474097d094040649f2162a627c0049b408f52138d980916788d80f04802f
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
