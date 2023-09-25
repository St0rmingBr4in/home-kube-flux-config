FROM gcr.io/datadoghq/agent:7.46.0
COPY datadog_fluxcd-0.0.1-py2.py3-none-any.whl /datadog_fluxcd-0.0.1-py2.py3-none-any.whl
RUN agent integration install -r -w /datadog_fluxcd-0.0.1-py2.py3-none-any.whl
