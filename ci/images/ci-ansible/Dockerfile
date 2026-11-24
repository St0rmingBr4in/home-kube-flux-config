FROM python:3.14-slim@sha256:22eafb370920ad8b429e0aec3fff433e0669968519f5d60469d83729c138b28b
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
